#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session qw/-ip_match/;

package Waiter::WWW;

sub login {
    # Create the cookie and such.
    my $session = shift;

    if ($session->is_empty) {
        $session = $session->new() or die $session->errstr;
    }
    $session->expire('~logged-in', '30m');
    $session->flush();

    my $cgi = CGI->new;
    my $cookie = $cgi->cookie(
        -name       => $session->name,
        -value      => $session->id
    );
    print $session->header(
            -location   => 'home.pl',
            -cookie     => $cookie
    );
}

sub logout {
    my $session = shift;

    $session->delete();
    $session->flush();
    print $session->header(
        -location   => 'index.pl'
    );
}

sub load_session {
    # Read session information and return the information as a hashref
    my $sess_name = shift;

    CGI::Session->name($sess_name);
    my $session = CGI::Session->load();
    return $session;
}

sub read_session {
    # Read session information and return the information as a hashref
    my $session = shift;

    my %data = ();
    # Read session parameters
    foreach my $key ($session->params()) {
        $data{$key} = $session->param($key);
    }
    # Read CGI parameters
    foreach my $key (params()) {
        $data{$key} = param($key);
    }
    return \%data;
}

sub save_session {
    # Take in the settings hash and store them in the session
    my $session = shift;
    my $data    = shift;

    foreach my $key (keys %$data) {
        $session->param($key,$$data{$key});
    }
    $session->flush();
}

1;
__END__
