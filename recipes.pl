#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if (Waiter::auth_user($$data{username},$$data{hash})) {
    my $userid = Waiter::get_userid($$data{username});
    if ($$data{recipe} and ($$data{recipe} ne '')) {
        if ($$data{recipe} eq 'new') {
            my $recipe_key = Waiter::create_new_recipe($userid);
            if ($recipe_key) {
                print $session->header(
                    -location   => "recipes.pl?recipe=$recipe_key"
                );
            } else {
                recipe_list_page('Failed to create recipe.');
            }
        } else {
            if (Waiter::is_recipe_owner($userid,$$data{recipe})) {
                recipe_modify_page($$data{recipe});
            } else {
                recipe_list_page('You cannot view that recipe.');
            }
        }
    } else {
        recipe_list_page();
    }
} else {
    # Non authenticated session, send to login page.
    print $session->header(
        -location   => 'index.pl'
    );
}

Waiter::WWW::save_session($session, $data);
exit;

sub recipe_modify_page {
    # Page for modifying a recipe.
    my $recipe_key  = shift;

    my $recipe = Waiter::get_recipe_by_key($recipe_key);
    my $details = "Edit Recipe: $recipe_key";
    if ($$recipe{name} and ($$recipe{name} ne '')) {
        $details .= " - $$recipe{name}";
    }

    my %checked = ();
    foreach my $time (split(/:/,$$recipe{vote_times})) {
        $checked{"time_$time"} = 'checked';
    }
    # Create the drop down selectors for setting wait duration
    my $min_list = Waiter::WWW::time_dropdown(
        'min','Minimum Duration:',$$recipe{min_time}
    );
    my $max_list = Waiter::WWW::time_dropdown(
        'max','Maximum Duration:',$$recipe{max_time}
    );
    my $start_list = Waiter::WWW::time_dropdown(
        'start','Start the Clock at:',$$recipe{start_time}
    );
    # Create the checkboxes for voting options
    my $time_checkboxes = Waiter::WWW::time_checkboxes($$recipe{vote_times});
    my $vote_options = Waiter::WWW::vote_options(
        $$recipe{min_votes},$$recipe{vote_cooldown}
    );
    #my $misc_options = Waiter::WWW::misc_options(
    #    $$recipe{start_rand},$$recipe{time_past},
    #    $$recipe{time_left},$$recipe{msg_times}
    #);

    Waiter::WWW::page_header($details,1);
    print qq{
    <form method='post'>
      <table class='options'>
        $start_list
        $min_list
        $max_list
      </table>
      <br/>
      <table class='options'>
        <caption>Voting Time Options</caption>
        $time_checkboxes
      </table>
      <br/>
      <table class='options'>
        $vote_options
      </table>
      <br/>
      <table class='options'>
        <tr valign='center'>
          <td><input type='submit' name='save' value='Save Recipe'></td>
          <td><input type='submit' name='rm' value='Delete Recipe'></td>
          <td>
            <input type='checkbox' id='confirm' name='confirm'>
            <label for='confirm'>Confirm Delete</label>
          </td>
        </tr>
      </table>
    </form>
};
    Waiter::WWW::page_footer();
}

sub recipe_list_page {
    my $error = shift || '';

    Waiter::WWW::page_header('Your Recipes',1);


    Waiter::WWW::page_footer($error);
}
