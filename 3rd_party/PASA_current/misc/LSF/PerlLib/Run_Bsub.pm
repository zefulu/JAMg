#!/usr/local/bin/perl


package Run_Bsub;

use strict;
use warnings;
use Bsub;
use vars qw ($log_dir $keep_logs_on_failure);
use Cwd;
use Carp;

our $CMDS_PER_NODE;  # by default, this is computed below. Set here specifically as needed.

my $NUM_NODES = 1000;

BEGIN {
    $log_dir = cwd;
    $keep_logs_on_failure = 1;
}


my $queue = "week";
my $memory = 4;
my $mount_test = undef;


sub set_queue {
	my ($q) = @_;
	$queue = $q;

	return;
}

sub set_memory {
	## Should be in G

	my ($m) = @_;
	$memory = $m;
}

sub set_mount_test {
	my ($mt) = @_;

	$mount_test = $mt;
}


sub set_log_dir {
    my ($log_dir_setting) = @_;

    unless (-d $log_dir_setting) {
        confess "Error, cannot find log directory $log_dir_setting";
    }

    $log_dir = $log_dir_setting;

    return;
}


sub run {
    my @cmds = @_;
    
    my $num_cmds = scalar @cmds;
    

    my ($cmds_per_node) = ($CMDS_PER_NODE) ? $CMDS_PER_NODE : (int($num_cmds / $NUM_NODES) + 1);
    
    
    my $bsubber = new Bsub({cmds=>\@cmds,
                            log_dir => $log_dir,
                            cmds_per_node => $cmds_per_node,
							queue => $queue,
							memory => $memory,
							mount_test => $mount_test,
							
						   }
                           );
    
    $bsubber->bsub_jobs();
    
    my $total_cmds = scalar (@cmds);

    if (my @failed_cmds = $bsubber->get_failed_cmds()) {
        
        my $num_failed_cmds = scalar (@failed_cmds);
        print "Sorry, $num_failed_cmds of $total_cmds failed = " . ($num_failed_cmds
                                                                    / $total_cmds * 100) . " % failure.\n";
        
        open (my $failed_fh, ">failed_cmds.$$") or die $!;
        foreach my $failed_cmd (@failed_cmds) {
            my $cmd = $failed_cmd->{cmd};
            my $ret = $failed_cmd->{ret};
            print $failed_fh "$cmd\nRET($ret)\n\n";
        }
        close $failed_fh;
        $bsubber->clean_logs() unless $keep_logs_on_failure;
        print "View file \'failed_cmds.$$\' for list of commands that failed.\n\n";
        return (1); # at least one job failed.
    }
    else {
        $bsubber->clean_logs();
        print "All $total_cmds completed successfully.\n\n";
        return (0); # all good.
    }

    
}


package main;
use strict;
use warnings;
use File::Basename;


#### Test routine, run by executing module directly:
if (basename($0) eq 'Run_Bsub.pm') {
    my $ret = &Run_Bsub::run("ls");
    if ($ret) {
        die "Error, test failed.\n";
    }
    else {
        print "Test ran successfully.\n";
    }
    
    exit($ret);
    
}



1;
