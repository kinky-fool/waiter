#!/usr/bin/perl

use strict;
use warnings;

use WaiterWWW;

login_page();
exit;

sub login_page {
    my $error = shift || '';

    Waiter::WWW::page_header('Welcome to The Waiting Game',0);
    print qq|
    <form method='post' action='home.pl'>
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
|;
    Waiter::WWW::page_footer($error);
}
