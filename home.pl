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

    my $status = qq|
    <p>Welcome $$data{username}!</p>
|;

    my $userid = Waiter::get_userid($$data{username});
    my $sessionid = Waiter::get_waiting_session($userid);
    if ($sessionid) {
        $status .= Waiter::WWW::session_status($sessionid);
    } else {
        $status .= qq|
    <p>Enter a Recipe Key to Begin Waiting!</p>
    <form method='post'>
    <table class='options'>
      </tr>
        <td><input type='text' name='recipe_key'></td>
        <td><input type='submit' name='begin' value='Begin Waiting'></td>
      </tr>
    </table>
    </form>
|;
    }
    my $messages = Waiter::WWW::messages_html($data);

    Waiter::WWW::page_header('The Waiting Game',1);

    print qq{
    $status
    $messages
};
    Waiter::WWW::page_footer($error);
}
