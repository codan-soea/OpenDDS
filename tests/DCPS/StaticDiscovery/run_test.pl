eval '(exit $?0)' && eval 'exec perl -S $0 ${1+"$@"}'
     & eval 'exec perl -S $0 $argv:q'
     if 0;

# -*- perl -*-

use lib "$ENV{ACE_ROOT}/bin";
use lib "$ENV{DDS_ROOT}/bin";
use PerlDDS::Run_Test;
use strict;

my $result = 0;
my $participant = 0;
my $entity = 0;
my $reliable = 1;

sub generateConfig {
    my $fh = shift;
    my $count = shift;
    my $participant_array = shift;
    my $readers = shift;
    my $reader_array = shift;
    my $writers = shift;
    my $writer_array = shift;

    for (my $j = 0; $j != $count; ++$j) {
        my $p = sprintf("%012x", $participant++);
        push($participant_array, "-participant $p");
        for (my $i = 0; $i != $readers; ++$i) {
            print $fh "[endpoint/Reader$i]\n";
            print $fh "domain=100\n";
            print $fh "participant=$p\n";
            my $e = sprintf("%06x", $entity++);
            push($reader_array, "-reader $e");
            print $fh "entity=$e\n";
            print $fh "type=reader\n";
            print $fh "config=Config\n";
            print $fh "topic=TheTopic\n";
            if ($reliable) {
                print $fh "datareaderqos=ReliableReader\n";
            } else {
                print $fh "datareaderqos=BestEffortReader\n";
            }
            print $fh "\n";
        }
        for (my $i = 0; $i != $writers; ++$i) {
            print $fh "[endpoint/Writer$i]\n";
            print $fh "domain=100\n";
            print $fh "participant=$p\n";
            my $e = sprintf("%06x", $entity++);
            push($writer_array, "-writer $e");
            print $fh "entity=$e\n";
            print $fh "type=writer\n";
            print $fh "config=Config\n";
            print $fh "topic=TheTopic\n";
            if ($reliable) {
                print $fh "datawriterqos=ReliableWriter\n";
            } else {
                print $fh "datawriterqos=BestEffortWriter\n";
            }
            print $fh "\n";
        }
    }
}

sub runTest {
    my $alpha_count = shift;
    my $alpha_readers = shift;
    my $alpha_writers = shift;

    my $beta_count = shift;
    my $beta_readers = shift;
    my $beta_writers = shift;

    my $delay = shift;

    my $test = new PerlDDS::TestFramework();
    $test->enable_console_logging();

    if ($test->flag('best_effort')) {
        $reliable = 0;
    }

    # Generate the config files.
    open(my $fh, '>', 'config.ini') or die "Could not open file 'config.ini' $!";
    print $fh "[common]\n";
    print $fh "DCPSDefaultDiscovery=DEFAULT_STATIC\n";
    print $fh "DCPSGlobalTransportConfig=Config\n";
    print $fh "\n";
    print $fh "[topic/TheTopic]\n";
    print $fh "name=TheTopic\n";
    print $fh "type_name=IDL:TestMsg/TestMsgTypeSupport:1.0\n";
    print $fh "max_message_size=300\n";
    print $fh "\n";
    print $fh "[config/Config]\n";
    print $fh "transports=Rtps\n";
    print $fh "\n";
    print $fh "[transport/Rtps]\n";
    print $fh "transport_type=rtps_udp\n";
    print $fh "local_address=localhost\n";
    print $fh "\n";
    print $fh "[datawriterqos/ReliableWriter]\n";
    print $fh "reliability.kind=RELIABLE\n";
    print $fh "reliability.max_blocking_time.sec=DURATION_INFINITE_SEC\n";
    print $fh "resource_limits.max_instances=10\n";
    print $fh "history.depth=10\n";
    print $fh "\n";
    print $fh "[datareaderqos/ReliableReader]\n";
    print $fh "reliability.kind=RELIABLE\n";
    print $fh "\n";
    print $fh "[datawriterqos/BestEffortWriter]\n";
    print $fh "reliability.kind=BEST_EFFORT\n";
    print $fh "\n";
    print $fh "[datareaderqos/BestEffortReader]\n";
    print $fh "reliability.kind=BEST_EFFORT\n";
    print $fh "\n";

    my @alpha_participant_array;
    my @alpha_reader_array;
    my @alpha_writer_array;
    generateConfig($fh, $alpha_count, \@alpha_participant_array, $alpha_readers, \@alpha_reader_array, $alpha_writers, \@alpha_writer_array);

    my @beta_participant_array;
    my @beta_reader_array;
    my @beta_writer_array;
    generateConfig($fh, $beta_count, \@beta_participant_array, $beta_readers, \@beta_reader_array, $beta_writers, \@beta_writer_array);
    close $fh;

    print "Spawning $alpha_count alphas\n";

    for (my $i = 0; $i != $alpha_count; ++$i) {
        $test->process("alpha$i", 'StaticDiscoveryTest', "-DCPSConfigFile config.ini -reliable $reliable $alpha_participant_array[$i] @alpha_reader_array @alpha_writer_array");
        $test->start_process("alpha$i");
    }

    sleep $delay;

    print "Spawning $beta_count betas\n";

    for (my $i = 0; $i != $beta_count; ++$i) {
        $test->process("beta$i", 'StaticDiscoveryTest', "-DCPSConfigFile config.ini -reliable $reliable $beta_participant_array[$i] @beta_reader_array @beta_writer_array");
        $test->start_process("beta$i");
    }

    my $res = $test->finish(150);
    if ($res != 0) {
        print STDERR "ERROR: test returned $res\n";
        $result += $res;
    }
}

# 1 process with 1 reader and 1 writer
runTest(1, 1, 1, 0, 0, 0, 0);
# 1 process with 1 reader, 1 process with 1 writer
#runTest(1, 1, 0, 1, 0, 1, 0);
# 1 process with 1 reader, 5 second delay, 1 process with 1 writer
#runTest(1, 1, 0, 1, 0, 1, 5);
# 1 process with 5 readers and 1 writer
#runTest(1, 5, 1, 0, 0, 0, 0);
# 1 process with 1 reader and 5 writers
#runTest(1, 1, 5, 0, 0, 0, 0);
# 5 processes with 5 readers and 5 writers
#runTest(5, 5, 5, 0, 0, 0, 0);

exit $result;
