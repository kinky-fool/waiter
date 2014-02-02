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

sub read_params {
    # Read session information and return the information as a hashref
    my $session = shift;

    my %data = ();
    # Read session parameters
    foreach my $key ($session->param()) {
        $data{$key} = $session->param($key);
    }
    # Read CGI parameters
    foreach my $key (CGI::param()) {
        $data{$key} = CGI::param($key);
    }
    # Attempt to replace 'password' with 'hash'
    if ($data{username} and $data{password}) {
        $data{hash} = Waiter::make_hash($data{username},$data{password});
        delete $data{password};
    }
    return \%data;
}

sub save_session {
    # Take in the settings hash and store them in the session
    my $session = shift;
    my $data    = shift;

    # Clear the params
    $session->clear();
    if ($$data{username} and ($$data{username} ne '')) {
        $session->param('username', $$data{username});
    }
    if ($$data{hash} and ($$data{hash} ne '')) {
        $session->param('hash', $$data{hash});
    }
    $session->expire('~logged-in', '30m');

    $session->flush();
}

sub page_header {
    my $title   = shift;
    my $logout  = shift || 0;

    my $logout_link = '';
    if ($logout) {
        $logout_link = "<p id='logout'><a href='logout.pl'>logout</a></p>";
    }
    print <<ENDL;
Content-Type: text/html; charset=ISO-8859-1
Cache-Control: no-cache, no-store, must-revalidate

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0;">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <title>$title</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <style type="text/css">\@import "style.css";</style>
  </head>
  <body>
  <div id='container'>
    $logout_link
    <h4>$title</h4>
ENDL
}

sub page_footer {
    my $error   = shift || '';
    $error = "<p><em>$error</em></p>" if ($error ne '');

    print qq{
    $error
  </div>
  </body>
</html>
};
}

1;
__END__
