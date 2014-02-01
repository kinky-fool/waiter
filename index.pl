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
        if (Waiter::auth_user($$data{username},$$data{hash})) {
            Waiter::WWW::save_session($session, $data);
            Waiter::WWW::login($session);
        } else {
            login_page('Invalid username or password.');
        }
    } else {
        login_page();
    }
} elsif (Waiter::auth_user($$data{username},$$data{hash})) {
    Waiter::WWW::save_session($session, $data);
    Waiter::WWW::login($session);
} else {
    Waiter::WWW::logout($session);
}

Waiter::WWW::save_session($session, $data);
exit;

sub login_page {
    my $error = shift || '';
    $error = "<p><em>$error</em></p>" if ($error ne '');

    Waiter::WWW::page_header('The Waiting Game Login Page','');
    print qq{
    <div id='container'>
        <form method='post'>
            <h4>The Waiting Game Login Page</h4>
            <table id='login'>
                <tr>
                    <td>username:</td>
                    <td><input type='text' name='username' size='15' /></td>
                </tr><tr>
                    <td>password:</td>
                    <td><input type='password' name='password' size='15'/></td>
                </tr><tr>
                    <td></td>
                    <td style='text-align: right; font-size: 6pt;'>
                        <a href='signup.pl'>sign up</a>
                    </td>
                </tr>
            </table>
            <input type='submit' name='action' value='login' />
        </form>
        <br/>
        $error
    </div>
    </body>
</html>};
}
