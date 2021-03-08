eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
    & eval 'exec perl -S $0 $argv:q'
    if 0;

# Executes test list files (*.lst), which contain commands with conditions
# called configurations under which the commands are run.

use strict;
use warnings;

# Intercept --dont-verify arguments to keep ConfigList.pm from parsing them.
# Don't do initial assignment to these variables because that won't play nice
# with BEGIN.
my @dont_verify_args;
my $dont_verify;
BEGIN {
    my @temp_argv = ();
    for my $arg (@ARGV) {
        if ($arg eq "--dont-verify") {
            $dont_verify = 1;
        }
        elsif ($dont_verify) {
            push(@dont_verify_args, $arg);
        }
        else {
            push(@temp_argv, $arg);
        }
    }
    @ARGV = @temp_argv;

    my @undefined_env_vars = grep {!defined($ENV{$_})} qw(ACE_ROOT DDS_ROOT);
    if (scalar(@undefined_env_vars)) {
        die(join(' and ', @undefined_env_vars) . " environment variable(s) must be defined");
    }
}

use Env qw(ACE_ROOT DDS_ROOT PATH);

use lib "$ACE_ROOT/bin";
use lib "$DDS_ROOT/bin";
use PerlDDS::Run_Test;
use FindBin;
use lib "$FindBin::Bin";
eval {require configured_tests;};
my $have_configured_tests = 1;
if ($@) {
    if ($@ =~ /Can't locate configured_tests/) {
        $have_configured_tests = 0;
    }
    else {
        die("Unexpected error in configured_tests.pm: $@");
    }
}

use Getopt::Long;
use Cwd;
use POSIX qw(SIGINT);

my $gh_actions = ($ENV{GITHUB_ACTIONS} || "") eq "true";

sub run_command {
    my $test = shift;
    my $command = shift;
    my $print_error = shift;

    my $result = 0;
    if (system($command)) {
        $result = $? >> 8;
        if ($print_error) {
            my $signal = $? & 127;
            my $coredump = $? & 128;
            my $error_message;
            if ($? == -1) {
                $error_message = "failed to run: $!";
            }
            elsif ($signal) {
                die("auto_run_tests: test interrupted") if ($signal == SIGINT);
                $error_message = sprintf("exited on signal %d", ($signal));
                $error_message .= " and created coredump" if ($coredump);
            }
            else {
                $error_message = sprintf("returned with status %d", $result);
            }
            print "auto_run_tests: Error: $test $error_message\n";
        }
    }
    return $result;
}

my @builtin_test_lists = (
    {
        name => 'dcps',
        file => "tests/dcps_tests.lst",
        default => 1,
    },
    {
        name => 'security',
        file => "tests/security/security_tests.lst",
    },
    {
        name => 'java',
        file => "java/tests/dcps_java_tests.lst",
    },
    {
        name => 'modeling',
        file => "tools/modeling/tests/modeling_tests.lst",
    },
);
my %builtin_test_lists_hash = map { $_->{name} => $_ } @builtin_test_lists;

sub print_usage {
    my $error = shift // 1;

    my $fd = $error ? *STDERR : *STDOUT;
    print $fd
        "auto_run_tests.pl [<options> ...] [<list_file> ...] [--dont-verify <options>]\n" .
        "auto_run_tests.pl -h | --help\n" .
        "\n";
    if ($error) {
        print STDERR "Use auto_run_tests.pl --help to see all the options\n";
        exit(1);
    }
}

sub print_help {
    print_usage(0);

    print
        "Executes test list files (*.lst), which contain commands with conditions called\n" .
        "configurations under which the commands are run.\n" .
        "\n" .
        "If the configure script was used with the --tests option, then this script will\n" .
        "will run all configured tests by default. It uses the configured_tests.pm file\n" .
        "that was generated by the configure script to set options that otherwise would\n" .
        "have to be done manually.\n" .
        "\n" .
        "Options:\n" .
        "    --help | -h              Display this help\n";

    my $indent = 29;
    foreach my $list (@builtin_test_lists) {
        my $prefix = "    --" . ($list->{default} ? "no-" : "");
        print sprintf("%s%-" . ($indent - length($prefix) - 1) . "s Include %s\n",
            $prefix, $list->{name}, $list->{file});
        print sprintf(" " x 29 . "%sncluded by default\n",
            $list->{default} ? "I" : "Not i");
    }

    print
        # These two are processed by PerlACE/ConfigList.pm
        "    -Config <cfg>            Include tests with <cfg> configuration\n" .
        "    -Exclude <cfg>           Exclude tests with <cfg> configuration\n" .
        "                             This is parsed as a Perl regex and will always\n" .
        "                             override -Config regardless of the order\n" .

        # This one is processed by PerlACE/Process.pm
        "    -ExeSubDir <dir>         Subdirectory for finding the executables\n" .

        "    --sandbox | -s <sandbox> Runs each program using a sandbox program\n" .
        "    --dry-run | -z           Do everything except run the tests\n" .
        "    --show-configs           Print possible values for -Config and -Excludes\n" .
        "                             broken down by list file\n" .
        "    --list-configs           Print combined set of the configs from the list\n" .
        "                             files\n" .
        "    --list-tests             List all the tests that would run\n" .
        "    --stop-on-fail | -x      Stop on any failure\n" .
        "    --no-auto-cfg            Don't automatically decide on test configurations,\n" .
        "                             which is done by default. If this is passed then\n" .
        "                             configurations must be set manually\n" .
        "                             Besides configured tests, this also disables\n" .
        "                             automatically setting:\n" .
        "                               -Config RTPS\n" .
        "                               -Config GH_ACTIONS if running on Github Actions\n" .
        "                               --modeling if setup.pl was run\n" .
        "    --verify                 Verify the automatic test configuration generated\n" .
        "                             by the configure script by passing in the expected\n" .
        "                             one. This will be enabled on CI by default. Use\n" .
        "                             --dont-verify to deviate from the configured tests\n" .

        # --dont-verify and its arguments are removed at the top of the script and separately
        "    --dont-verify ...        All arguments after --dont-verify are applied in\n" .
        "                             addition to the previous ones to run a different\n" .
        "                             set of tests than what configure_tests.pm defined\n" .
        "                             while still enabling verification of\n" .
        "                             configure_tests.pm. This can be used to avoid\n" .
        "                             running tests that already have sufficient\n" .
        "                             coverage elsewhere.\n" .
        "                             The following options are the only valid options\n" .
        "                             that can used after --dont-verify:\n" .
        "                               -Config\n" .
        "                               -Exclude\n" .
        "                               --unexclude (remove a verified exclude)\n";

    for my $list (@builtin_test_lists) {
        print " " x ($indent + 2) . "--[no-]$list->{name}\n";
    }

    exit(0);
}

# Parse Options
my $help = 0;
my $sandbox = '';
my $dry_run = 0;
my $show_configs = 0;
my $list_configs = 0;
my $list_tests = 0;
my $stop_on_fail = 0;
my $auto_cfg = 1;
my $verify = $gh_actions;
my %opts = (
    'help|h' => \$help,
    'sandbox|s=s' => \$sandbox,
    'dry-run|z' => \$dry_run,
    'show-configs' => \$show_configs,
    'list-configs' => \$list_configs,
    'list-tests' => \$list_tests,
    'stop-on-fail|x' => \$stop_on_fail,
    'auto-cfg!' => \$auto_cfg,
    'verify!' => \$verify,
);
my @dont_verify_configs = ();
my @dont_verify_excludes = ();
my @dont_verify_unexcludes = ();
my %dont_verify_opts = (
    'Config=s' => \@dont_verify_configs,
    'Exclude=s' => \@dont_verify_excludes,
    'unexclude=s' => \@dont_verify_unexcludes,
);
foreach my $list (@builtin_test_lists) {
    if (!exists($list->{default})) {
        $list->{default} = 0;
    }
    $list->{option} = undef;
    $list->{dont_verify_option} = undef;
    my $opt = "$list->{name}!";
    $opts{$opt} = \$list->{option};
    $dont_verify_opts{$opt} = \$list->{dont_verify_option};
}
Getopt::Long::Configure('bundling', 'no_auto_abbrev');
if (!GetOptions(%opts)) {
    print_usage(1);
}
elsif ($help) {
    print_help();
}
for my $list (@builtin_test_lists) {
    if (!exists($list->{enabled})) {
        $list->{enabled} = defined($list->{option}) ? $list->{option} : $list->{default};
    }
}
my $query = $show_configs || $list_configs || $list_tests;
die("--dont-verify requires --verify") if ($dont_verify && !$verify);
die("--verify requires --auto-cfg") if ($verify && !$auto_cfg);
die("--verify requires tests/configured_tests.pm") if ($verify && !$have_configured_tests);

if ($auto_cfg) {
    # Because it's always configured separately from the configure script,
    # include modeling if modeling_tests.mwc exists and --no-modeling wasn't
    # passed.
    if (!defined($builtin_test_lists_hash{modeling}->{option}) &&
            -r "$DDS_ROOT/tools/modeling/tests/modeling_tests.mwc") {
        $builtin_test_lists_hash{modeling}->{enabled} = 1;
    }

    if ($have_configured_tests) {
        foreach my $list_name (@configured_tests::lists) {
            die("Invalid list name \"$list_name\" from configured_tests::lists")
                if (!exists($builtin_test_lists_hash{$list_name}));
        }

        if (!$query) {
            print("Configured Test Lists: " . join(',', @configured_tests::lists) . "\n");
            print("Configured Configs: " . join(',', @configured_tests::includes) . "\n");
            print("Configured Excludes: " . join(',', @configured_tests::excludes) . "\n");
        }

        if ($verify) {
            # Verify configure_tests.pm against arguments
            my @verify_failures = ();

            sub check_missing {
              my $expected_list = shift;
              my $generated_list = shift;
              my $what = shift;

              sub _check_missing {
                my $a = shift;
                my $b = shift;
                my $b_is_generated = shift;
                my $what = shift;

                my @kinds = ("expected", "generated");
                my $a_kind = $kinds[!$b_is_generated];
                my $b_kind = $kinds[$b_is_generated];
                my %b_hash = map { $_ => 1} @{$b};
                for my $i (@{$a}) {
                  if (!exists($b_hash{$i})) {
                    push(@verify_failures, "\"$i\" is is present in $a_kind $what, " .
                        "but is missing from $b_kind $what");
                  }
                }
              }
              _check_missing($generated_list, $expected_list, 0, $what);
              _check_missing($expected_list, $generated_list, 1, $what);
            }

            my @enabled_lists = map {$_->{name}} (grep { $_->{enabled} } @builtin_test_lists);
            my @configured_lists = (
                @configured_tests::lists,
                (map {$_->{name}} (grep { $_->{default} } @builtin_test_lists))
            );
            check_missing(\@enabled_lists, \@configured_lists, "list files");
            check_missing(\@PerlACE::ConfigList::Configs, \@configured_tests::includes, "configs");
            check_missing(\@PerlACE::ConfigList::Excludes, \@configured_tests::excludes, "excludes");
            if (scalar(@verify_failures)) {
                print STDERR
                    "auto_run_tests: Error: Verification of configured tests failed:\n" .
                    join("\n", map {"  $_"} @verify_failures) . "\n" .
                    "Make sure auto_run_test.pl arguments are correct. If you are sure the arguments\n" .
                    "are correct, then the configured_test.pm generated by the configured script\n" .
                    "might be incorrect or you should use --dont-verify to run different tests from\n" .
                    "what configured_test.pm is set up for. See --help for details.\n";
                exit(1);
            }
        }
        else {
            # Add configured tests
            foreach my $list_name (@configured_tests::lists) {
                if (exists($builtin_test_lists_hash{$list_name})) {
                    $builtin_test_lists_hash{$list_name}->{enabled} = 1;
                }
            }
            push(@PerlACE::ConfigList::Configs, @configured_tests::includes);
            push(@PerlACE::ConfigList::Excludes, @configured_tests::excludes)
        }
    }

    # Test configuration after this avoids having to be verified.

    push(@PerlACE::ConfigList::Configs, "RTPS");
    if ($gh_actions) {
        push(@PerlACE::ConfigList::Configs, 'GH_ACTIONS');
    }
}

if ($dont_verify) {
    Getopt::Long::Configure('no_bundling', 'no_auto_abbrev');
    if (!Getopt::Long::GetOptionsFromArray(\@dont_verify_args, %dont_verify_opts)) {
        print STDERR ("Note: the valid options after --dont-verify are different from" .
            "the normal options. See --help.\n");
        print_usage();
    }
    for my $list (@builtin_test_lists) {
        if (defined($list->{dont_verify_option})) {
            $list->{enabled} = $list->{dont_verify_option};
        }
    }
    for my $config (@dont_verify_configs) {
        push(@PerlACE::ConfigList::Configs, $config);
    }
    for my $exclude (@dont_verify_excludes) {
        push(@PerlACE::ConfigList::Excludes, $exclude);
    }
    for my $unexclude (@dont_verify_unexcludes) {
        @PerlACE::ConfigList::Excludes = grep {$_ ne $unexclude} @PerlACE::ConfigList::Excludes;
    }
}

# Determine what test list files to use
my @file_list = ();
foreach my $list (@builtin_test_lists) {
    push(@file_list, "$DDS_ROOT/$list->{file}") if ($list->{enabled});
}
push(@file_list, @ARGV);
if ($dont_verify) {
    # These are the positional arguments after --dont-verify
    push(@file_list, @dont_verify_args);
}
foreach my $list (@file_list) {
    die("$list is not a readable file!") if (!-r $list);
}

if ($show_configs) {
    foreach my $test_list (@file_list) {
        my $config_list = new PerlACE::ConfigList;
        $config_list->load($test_list);
        print "$test_list: " . $config_list->list_configs() . "\n";
    }
    exit(0);
}

if ($list_configs) {
    my %configs = ();
    foreach my $test_list (@file_list) {
        my $config_list = new PerlACE::ConfigList;
        $config_list->load($test_list);
        for my $config (split(/ /, $config_list->list_configs())) {
            $configs{$config} = 1;
        }
    }
    for my $config (sort(keys(%configs))) {
        print("$config\n");
    }
    exit(0);
}

if (!$query) {
    print("Test Lists:" . join(',', @file_list) . "\n");
    print("Configs: " . join(',', @PerlACE::ConfigList::Configs) . "\n");
    print("Excludes: " . join(',', @PerlACE::ConfigList::Excludes) . "\n");
}

foreach my $test_lst (@file_list) {

    my $config_list = new PerlACE::ConfigList;
    $config_list->load($test_lst);

    # Ensures that we search for stuff in the current directory.
    $PATH .= $Config::Config{path_sep} . '.';

    foreach my $test ($config_list->valid_entries()) {
        if ($list_tests) {
            print("$test\n");
            next;
        }

        my $directory = ".";
        my $program = ".";

        ## Remove intermediate '.' directories to allow the
        ## scoreboard matrix to read things correctly
        $test =~ s!/./!/!g;

        if ($test =~ /(.*)\/([^\/]*)$/) {
            $directory = $1;
            $program = $2;
        }
        else {
            $program = $test;
        }

        print "auto_run_tests: $test\n";

        chdir($DDS_ROOT."/$directory")
            || die "auto_run_tests: Error: Cannot chdir to $DDS_ROOT/$directory";

        my $subdir = $PerlACE::Process::ExeSubDir;
        my $progNoArgs = $program;
        if ($program =~ /(.*?) (.*)/) {
            $progNoArgs = $1;
            if (! -e $progNoArgs) {
                print STDERR "auto_run_tests: Error: $directory.$1 does not exist\n";
                next;
            }
        }
        else {
            my $cmd = $program;
            $cmd = $subdir.$cmd if ($program !~ /\.pl$/);
            if ((! -e $cmd) && (! -e "$cmd.exe")) {
                print STDERR "auto_run_tests: Error: $directory/$cmd does not exist\n";
                next;
            }
        }

        ### Generate the -ExeSubDir and -Config options
        my $inherited_options = " -ExeSubDir $subdir ";

        foreach my $config ($config_list->my_config_list()) {
            $inherited_options .= " -Config $config ";
        }

        my $cmd = '';
        $program = "perl $program" if ($progNoArgs =~ /\.pl$/);
        if ($sandbox) {
            $cmd = "$sandbox \"$program $inherited_options\"";
        }
        else {
            $cmd = $program.$inherited_options;
            $cmd = $subdir.$cmd if ($progNoArgs !~ /\.pl$/);
        }

        my $result = 0;
        my $start_time = time();
        if ($dry_run) {
            my $cwd = getcwd();
            print "In \"$cwd\" would run:\n    $cmd\n";
        }
        else {
            $result = run_command($test, $cmd, 1);
        }
        my $time = time() - $start_time;
        print "\nauto_run_tests_finished: $test Time:$time"."s Result:$result\n";
        print "==============================================================================\n";

        if ($result && $stop_on_fail) {
            exit(1);
        }
    }
}

# vim: expandtab:ts=4:sw=4
