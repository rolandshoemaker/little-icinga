#!/usr/bin/perl

# little-icinga
# command-line direct push of icinga hosts/service status and scheduled daemon-pusher 
# july 2014 - roland shoemaker

use strict;
use warnings;
no warnings 'experimental::smartmatch';

use HTML::Template;
use Getopt::Std;
use LWP::UserAgent;


#DEBUG#
use Data::Dumper;
#DEBUG#

$main::VERSION = '0.1';

# lets quickly check if you're root (or running as sudo) before we start since icli requires privileged access (generally)
if ($> != 0) {
	print "This script must be run as root! (or via sudo...)\n";
	exit(0);
}

# set secret from envar LITTLESECRET, icli binary, and options from cmd line
my $littlesecret = $ENV{'LITTLESECRET'} if defined $ENV{'LITTLESECRET'};
my $icli = "/usr/bin/icli";
my $title = "Little Icinga<br/>v".$main::VERSION;


my %options;
if (!getopts("t:s:h:d:Hv", \%options)) {
	&HELP_MESSAGE();
	exit(0);
}

# check sanity of opts
if ($options{d} && scalar(%options) ne '1/8') {
	print "You can't use -d with any other options...\n\n";
	&HELP_MESSAGE();
	exit(0);
} elsif ($options{t} && scalar(%options) ne '1/8') {
	print "You can't use -t with any other options...\n\n";
	&HELP_MESSAGE();
	exit(0);
} elsif ($options{h} && $options{H}) {
	print "You can't specify both specific hosts and all hosts...\n\n";
	&HELP_MESSAGE();
	exit(0);
} elsif ($options{H} && scalar(%options) eq '1/8') {
	print "You need to specify -s with -H...\n\n";
	&HELP_MESSAGE();
	exit(0);
}

# execute option dependent subroutines

if (scalar(%options) eq '0') {
	# default, no options
	my %hosts = &get_hosts();
	&send_html(%hosts);
}

my %services;
my %hosts;

if ($options{h}) {
	# specific hosts
	my @optHosts = split(',', $options{h});
	%hosts = &get_hosts(@optHosts);
}

if ($options{s}) {
	if ($options{H}) {
		# all hosts as well (run default sub)
	}

        # specific services
}

if ($options{d} && scalar(%options) eq '1/8') {
        # run daemon mode
	print "d\n";
}

if ($options{t} && scalar(%options) eq '1/8') {
        # run conf test sub
	exit(1);
}

# if just printing from command line (-s/-h, not -d/-t) run the final output sub (same thing that daemon uses in a loop)  
if ($options{s} || $options{h}) {
	&send_html(%hosts);
	exit(0);
}


print $littlesecret."\n" if defined $littlesecret;

sub get_hosts() {
	my %hostInfo;
        my @outputUp = `$icli -z o -C -l hosts`;
        my @outputDown = `$icli -z D -C -l hosts`;

	my @someHosts = @_ if @_;

	@outputUp = `$icli -z o -C -l hosts`;
        @outputDown = `$icli -z D -C -l hosts`;

	foreach (@outputUp) {
		my @line = split(' ', $_);
		if ((@someHosts && $line[0] ~~ @someHosts) || (!@someHosts)) {
			$hostInfo{$line[0]}[0] = 'up';
			# $hostInfo{$line[0]}[1] = join(' ', @line[2..(scalar(@line)-1)]);
		}
	}
	foreach (@outputDown) {
		my @line = split(' ', $_);
                $hostInfo{$line[0]}[0] = 'down';
		$hostInfo{$line[0]}[1] = join(' ', @line[2..(scalar(@line)-1)]);
        }

	return %hostInfo;
}

sub get_services() {

}

sub test_conf() {

}

sub send_html() {
	my (%host, %service) = @_;
	my $template = HTML::Template->new(filename => 'little-icinga.tmpl');
	my @host_data;
	my @service_data;

	foreach my $key (keys %host) {
		my %row;
		$row{HOSTNAME} = $key;
		$row{STATUS} = $host{$key}[0];
		push(@host_data, \%row);
	}

	$template->param(HOSTSTATUS => \@host_data);
	$template->param(TITLE => $title);

	print $template->output;

	my $ua = LWP::UserAgent->new;
	#my $endpoint = "http://remote.bergcloud.com/playground/direct_print/".$littlesecret;
	my $endpoint = "http://requestb.in/waxdyuwa";
	my $direct = $ua->post($endpoint, {'html' => $template->output});
}

sub daemon() {

}

sub HELP_MESSAGE() {
	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	print "simple tool utilizing the Little Printer direct push API to deliver Icinga Host/Service status instantaneously or based on a schedule\n";
	print "\nArguments:\n";
	print "    Default : Prints host status for all hosts set on in your Icinga configuration to Little Printer set in envar LITTLESECRET\n";
	print "    -h : Specify a list of hosts seperated by commas to check (only this information will be printed), e.g. little-printer -h host1,host2,host3\n";
	print "    -s : Specify a list of services to check on a host seperated by commas to check (only this information will be printed), e.g. little-printer -s host1:service1,host2:'service2 space name',host3:service3\n";
	print "        -Hs : Prints all host statuses and specified service statuses\n";
	print "    -d : Run in daemon mode with specified daemon configuration file, e.g. little-printer -d schedule.conf\n";
	print "    -t : Test specified daemon configuration file, e.g. little-printer -t schedule.conf\n";
	print "    -v : Enable verbose mode (cannot be used with -d, verbose mode can be set in the conf file), e.g. little-printer -v\n";
}

sub VERSION_MESSAGE() {
	$Getopt::Std::STANDARD_HELP_VERSION = 1;
	print "little-icinga version ".$main::VERSION." written by roland shoemaker\n";
}
