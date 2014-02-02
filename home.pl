#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if (Waiter::auth_user($$data{username},$$data{hash})) {
    home_page($data);
} else {
    # Non authenticated session, send to login page.
    print $session->header(
        -location   => 'index.pl'
    );
}

Waiter::WWW::save_session($session, $data);
exit;

sub home_page {
    # The main page
    my $data    = shift;
    my $error   = shift || '';

    my $information = Waiter::WWW::information_html($$data{user});
    my $messages = Waiter::WWW::messages_html($data);
    my $links = '';

    Waiter::WWW::page_header('The Waiting Game Home Page',1);

    print qq{
    $information
    $messages
    $links
};
    Waiter::WWW::page_footer($error);
}
