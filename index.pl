#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_session($session);

# Attempt to replace 'password' with 'hash'
if ($$data{username} and $$data{password}) {
    $$data{hash} = Waiter::make_hash($$data{username},$$data{password});
    delete $$data{password};
}

if ($session->is_expired) {
    login_page('You have been logged out.');
} elsif ($session->is_empty) {
    if ($$data{action} and ($$data{action} eq 'login')) {
        delete $$data{action};
        if (Waiter::WWW::auth_user($$data{username},$$data{hash})) {
            Waiter::WWW::save_session($session, $data);
            Waiter::WWW::login($session);
        } else {
            login_page('Invalid username or password.');
        }
    } else {
        login_page();
    }
} elsif (Waiter::WWW::auth_user($$data{username},$$data{hash})) {
    Waiter::WWW::save_session($session, $data);
    Waiter::WWW::login($session);
} else {
    login_page('Invalid Session.');
}

Waiter::WWW::save_session($session, $data);
exit;
