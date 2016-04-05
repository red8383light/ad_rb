#!/usr/bin/perl -w

use strict;
use Time::Piece;
use Getopt::Std;
use Switch;
use Fcntl;
use POSIX qw(mkfifo);

my $fifo = '/var/run/ad_rb.fifo';
my $fifoh;
our %matrix;
our $unique_removals = 2; #<-- Amount of different groups user removed from
our $time_diff = 600; #<-- Amount of time for failed connections to occur within
our @ignore = (); #<-- Hosts to ignore ('192.168.1.1','192.168.1.2','192.168.1.3')

my %options=();
getopts('dDhH', \%options);
if($options{d} or $options{D}){
        exec("echo 'Print Debug' >> $fifo");
        exit 0;
}elsif($options{h} or $options{H}){
        print "ad_rb_correlator -(dD) <-- Debug -(hH) <-- This help menu\n";
        exit 0;
        }

#Die if already running
my @pids = `pgrep "ad_rb_correlato"`;
if( $#pids > 0){die"ad_rb_correlator is already running!\n";}

if( ! -p $fifo){
       mkfifo($fifo, 0644) || die "Failed to make fifo $fifo: $!";
       }

sysopen($fifoh, $fifo, O_RDONLY) || die "Can't open FIFO: $!";

while(<$fifoh>) {
        chomp ($_);
        my @a;my @match;my @matches0;my @matches1;my @epoch_time;my $count;my $min;my $max;my $epoch;my $out=0;my $bro;my $other='';
	my $t;my @uname;my @uname2;my @name;my $af_username;my @aname;my @dname;my $admin_username;my $ad_name;my @gname;my @sname;
	my $group_name;

        switch($_){
        case /\| 4729:/ { $t = 4729; @a = split/\| 4729:/, $_;}
	case /\| 4733:/ { $t = 4733; @a = split/\| 4733:/, $_;}
	case /\| 4747:/ { $t = 4747; @a = split/\| 4747:/, $_;}
        case /\| 4757:/ { $t = 4757; @a = split/\| 4757:/, $_;}
        case /\| 4762:/ { $t = 4762; @a = split/\| 4762:/, $_;}
        else            { $other = $_;}
        }

        if(scalar(@a) > 1){

                        @aname = split/Account Name:/, $a[1];
                        @dname = split/Account Domain:/, $aname[1];
			$dname[0] =~ s/^\s+|\s+$//g;
                        $admin_username = $dname[0];

                        @uname = split/ CN=/, $a[1];
                        @name = split/,/, $uname[1];
                        $name[0] =~ s/^\s+|\s+$//g;
                        $af_username = $name[0];

			@gname = split/Group Name:/, $a[1];
			@sname = split/Group Domain:/, $gname[1];
			$sname[0] =~ s/^\s+|\s+$//g;
			$group_name = $sname[0];

                $epoch = localtime->strftime('%s');

                $matrix{$af_username}{$t} = "$epoch:$admin_username:$group_name";
                $count = scalar(keys %{$matrix{$af_username}});

                if($count >= $unique_removals){
			
			my @all_values = values %{$matrix{$af_username}};
			my @times;
			foreach my $splitting (@all_values){
				push @times, (split/:/, $splitting)[0];
				}
			($max) = sort { $b <=> $a } @times;
                        $min = $max - $time_diff;
                        foreach my $event (keys %{$matrix{$af_username}}){
                                if((split/:/,$matrix{$af_username}{$event})[0] < $min){
                                   delete $matrix{$af_username}{$event};
                                    $out++;
                                }
                           }
                        if($out > 0){next;}
                        #This will be where we print our sagan-event
                        my $filename = '/var/log/ad_rb-correlation.log';
                        my $dt = localtime->strftime('%c');
                        open(my $fhl, '>>', $filename) or die "I can't open it boss '$filename' $!";
                        print $fhl "$af_username has been removed from:";
                           foreach my $removed (sort { $b <=> $a } keys %{ $matrix{$af_username} }) {
			   	my $all_data = $matrix{$af_username}{$removed};
				my $a0 = (split/:/, $all_data)[0];
				my $a1 = (split/:/, $all_data)[1];
				my $a2 = (split/:/, $all_data)[2];
                                print $fhl " 'Group=$a2 Admin=$a1 Time=$a0'";
                                }
                        print $fhl "\n";
                        close $fhl;
                        delete $matrix{$af_username};
                }

        }else{
                 if(length($other) == 11 && $other eq 'Print Debug'){
                        my $filename = '/var/log/ad_rb-correlation-debug.log';
                        my $dt = localtime->strftime('%c');
                        open(my $fh, '>>', $filename) or die "I can't open it boss '$filename' $!";
                        print $fh "ad_rb Debug for $dt\n";
                        print $fh "#######################################################\n";
                        foreach my $all_users (sort keys %matrix) {
                                foreach my $un_removes (keys %{ $matrix{$all_users} }) {
				my $t = scalar localtime $matrix{$all_users}{$un_removes};
                                print $fh "$all_users -> $un_removes @ $t\n";
                                }
                            }
                        print $fh "#######################################################\n";
                        print $fh "-------------------------------------------------------\n\n";
                        close $fh;
                        }
                next;
        }# Close else

}# Close our Fifo
close $fifoh;
exit 0;
