eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
     & eval 'exec perl -S $0 $argv:q'
     if 0;

use lib "$ENV{ACE_ROOT}/bin";
use lib "$ENV{DDS_ROOT}/bin";
use PerlDDS::Run_Test;
use Getopt::Long;
use strict;

my $test = new PerlDDS::TestFramework();
$test->enable_console_logging();

my $verbose = 0;
GetOptions(
  "verbose" => \$verbose,
);

my @common_args = ('-DCPSConfigFile', 'rtps_disc.ini');
push(@common_args, "--verbose") if ($verbose);

my @reader_args = ('--reader');
push(@reader_args, @common_args);
$test->process('reader', 'XTypes', join(' ', @reader_args));
$test->start_process('reader');

my @writer_args = ('--writer');
push(@writer_args, @common_args);
$test->process('writer', 'XTypes', join(' ', @writer_args));
$test->start_process('writer');

exit $test->finish(60);
