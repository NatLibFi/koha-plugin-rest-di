package Koha::Plugin::Fi::KohaSuomi::DI::PatronController;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use C4::Auth qw( checkpw haspermission track_login_daily );

use Koha::Biblios;
use Koha::Patron::Messages;
use Koha::Patron::Modification;

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Patron;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Patron::Message::Preferences;

=head1 Koha::Plugin::Fi::KohaSuomi::DI::PatronController

A class implementing the controller methods for the patron-related API

=head2 Class Methods

=head3 get

Get borrower

=cut

sub get {
    my $c = shift->openapi->valid_input or return;

    return try {
        my $patron = Koha::Patrons->find($c->validation->param('patron_id'));
        unless ($patron) {
            return $c->render(
                status  => 404,
                openapi => {error => 'Patron not found'}
            );
        }

        my $ret = $patron->to_api;

        if ($c->validation->param('query_blocks')) {
            my $patron_checks = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Patron->new($patron);

            my %blocks;
            my $ex;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->debarred;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->debt_hold;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->debt_checkout_guarantees;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->exceeded_maxreserves;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->expired;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->gonenoaddress;
            $blocks{ref($ex)} = $ex if $ex = $patron_checks->lost;

            $ret->{blocks} = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability->to_api_exception(\%blocks);
        }

        if ($c->validation->param('query_relationships')) {
            my @guarantors;
            my $guarantor_relationships = $patron->guarantor_relationships;
            while (my $guarantor = $guarantor_relationships->next()) {
                my $api_record;
                my $guarantor_record = $guarantor->guarantor;
                $api_record->{relationship} = $guarantor->relationship;
                $api_record->{id} = $guarantor->guarantor_id;
                $api_record->{surname} = $guarantor_record->surname;
                $api_record->{firstname} = $guarantor_record->firstname;
                push @guarantors, $api_record;
            }

            # We need to check if relationship column exists, it was dropped in bug 26995
            my $relationship = exists $ret->{'relationship_type'} ? $patron->relationship : undef;
            if ($relationship && $patron->contactname) {
                my $api_record;
                $api_record->{'relationship'} = $relationship;
                $api_record->{'surname'} = $patron->contactname;
                $api_record->{'firstname'} = $patron->contactfirstname;
                push @guarantors, $api_record;
            }

            my @guarantees;
            my $guarantee_relationships = $patron->guarantee_relationships;
            while (my $guarantee = $guarantee_relationships->next()) {
                my $api_record;
                my $guarantee_record = $guarantee->guarantee;
                $api_record->{relationship} = $guarantee->relationship;
                $api_record->{id} = $guarantee->guarantee_id;
                $api_record->{surname} = $guarantee_record->surname;
                $api_record->{firstname} = $guarantee_record->firstname;
                push @guarantees, $api_record;
            }

            $ret->{guarantors} = \@guarantors;
            $ret->{guarantees} = \@guarantees;
        }

        if ($c->validation->param('query_messaging_preferences')) {
            if ( ! C4::Context->preference('EnhancedMessagingPreferences') ) {
                return $c->render( 
                    status => 403, 
                    openapi => { error => "Enhanced messaging preferences are not enabled" }
                );
            }

            $ret->{messaging_preferences} = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Patron::Message::Preferences->search(
                { borrowernumber => $patron->borrowernumber }
            );
        }

        if ($c->validation->param('query_permissions')) {
            my $raw_permissions = C4::Auth::haspermission($patron->userid); # defaults to all permissions
            my @permissions;

            # delete all empty permissions
            while ( my ($key, $val) = each %{$raw_permissions} ) {
                push @permissions, $key if $val;
            }
            $ret->{permissions} = \@permissions;
        }

        if ($c->validation->param('query_messages')) {
            my $raw_messages = Koha::Patron::Messages->search(
                {
                    borrowernumber => $patron->borrowernumber,
                    message_type => 'B',
                },
                {
                    order_by => ['message_id']
                }
            );
            my @messages;

            while (my $message = $raw_messages->next()) {
                my $api_record;
                $api_record->{date} = $message->message_date;
                $api_record->{message} = $message->message;
                $api_record->{library_id} = $message->branchcode;
                push @messages, $api_record;
            }
            $ret->{messages} = \@messages;
        }

        if ($patron->is_going_to_expire) {
            $ret->{expiry_date_near} = 1;
        }

        return $c->render(status => 200, openapi => $ret);
    } catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(status => 500, openapi => { error => $_->msg });
        }
        else {
            return $c->render( status => 500, openapi =>
                { error => "Something went wrong, check the logs." });
        }
    };
}

sub update {
    my $c = shift->openapi->valid_input or return;

    if (!C4::Context->preference('OPACPatronDetails')) {
        return $c->render( 
            status => 403,
            openapi => { error => "Preferences do not allow changing patrons details"}
        );
    }

    return try {
        my $patron_id = $c->validation->param('patron_id');
        my $patron = Koha::Patrons->find($patron_id);
        return $c->render(status => 404, openapi => {error => "Patron not found"}) unless $patron;
        my $body = $c->req->json;

        my $verification = _parameters_require_modification_request($body);
        if (keys %{$verification->{not_required}}) {
            # Update changes
            $patron->set_from_api($verification->{not_required})->store();
            $patron->discard_changes();

            unless (keys %{$verification->{required}}) {
                return $c->render( status => 200, openapi => $patron );
            }
        }
        if (keys %{$verification->{required}}) {
            # Map from API field names
            my $changes = {};
            my $from_api_mapping = $patron->from_api_mapping;
            while (my ($key, $value) = each %{ $verification->{required} } ) {
                $changes->{$from_api_mapping->{$key} // $key} = $value;
            }
            $changes->{changed_fields} = join ',', keys %{$changes};
            $changes->{borrowernumber} = $patron_id;
            
            Koha::Patron::Modifications->search({ borrowernumber => $patron_id })->delete;
            Koha::Patron::Modification->new($changes)->store();

            return $c->render(status => 202, openapi => {});
        }
    }
    catch {
        if ($_->isa('Koha::Exceptions::Patron::DuplicateObject')) {
            return $c->render(status => 409, openapi => { error => $_->error, conflict => $_->conflict });
        }
        elsif ($_->isa('Koha::Exceptions::Library::BranchcodeNotFound')) {
            return $c->render(status => 400, openapi => { error => "Library with branchcode \"".$_->branchcode."\" does not exist" });
        }
        elsif ($_->isa('Koha::Exceptions::Category::CategorycodeNotFound')) {
            return $c->render(status => 400, openapi => {error => "Patron category \"".$_->categorycode."\" does not exist"});
        }
        elsif ($_->isa('Koha::Exceptions::MissingParameter')) {
            return $c->render(status => 400, openapi => {error => "Missing mandatory parameter(s)", parameters => $_->parameter });
        }
        elsif ($_->isa('Koha::Exceptions::BadParameter')) {
            return $c->render(status => 400, openapi => {error => "Invalid parameter(s)", parameters => $_->parameter });
        }
        elsif ($_->isa('Koha::Exceptions::NoChanges')) {
            return $c->render(status => 204, openapi => {error => "No changes have been made"});
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

=head3 purge_checkout_history

Deletes all items from checkout history

=cut

sub purge_checkout_history {
    my $c = shift->openapi->valid_input or return;

    my $borrowernumber = $c->validation->param('patron_id');
    my $patron;
    return try {
        $patron = Koha::Patrons->find({
            'me.borrowernumber' => $borrowernumber
        });
        $patron->old_checkouts->anonymize;
        
        return $c->render( status => 204, openapi => {} );
    }
    catch {
        unless ($patron) {
            return $c->render( status => 404, openapi => {
                error => "Patron doesn't exist"
            });
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}


=head3 edit_messaging_preferences

Updates messaging preferences

=cut

sub edit_messaging_preferences {
    my $c = shift->openapi->valid_input or return;

    if (!C4::Context->preference('EnhancedMessagingPreferences')) {
        return $c->render( 
            status => 403, 
            openapi => { error => "Enhanced messaging preferences are not enabled" }
        );
    }

    if (!C4::Context->preference('EnhancedMessagingPreferencesOPAC')) {
        return $c->render( 
            status => 403, 
            openapi => { error => "Updating of enhanced messaging preferences in OPAC not enabled" }
        );
    }

    my $borrowernumber = $c->validation->param('patron_id');
    my $body           = $c->validation->param('body');

    my $found = Koha::Patrons->find($borrowernumber);

    return try {
        die unless $found;
        my $actionLog = [];
        foreach my $in (keys %{$body}) {
            my $preference =
                Koha::Plugin::Fi::KohaSuomi::DI::Koha::Patron::Message::Preferences->find_with_message_name({
                    borrowernumber => $borrowernumber,
                    message_name => $in
                });

            # Format wants_digest and days_in_advance values
            my $wants_digest = $body->{$in}->{'digest'} ?
                $body->{$in}->{'digest'}->{'value'} ? 1 : 0 : $preference ?
                $preference->wants_digest ? 1 : 0 : 0;
            my $days_in_advance = $body->{$in}->{'days_in_advance'} ?
                defined $body->{$in}->{'days_in_advance'}->{'value'} ?
                    $body->{$in}->{'days_in_advance'}->{'value'} : undef : undef;

            # HASHref for updated preference
            my @transport_types;
            foreach my $mtt (keys %{$body->{$in}->{'transport_types'}}) {
                if ($body->{$in}->{'transport_types'}->{$mtt}) {
                    push @transport_types, $mtt;
                }
            }
            my $edited_preference = {
                wants_digest => $wants_digest,
                days_in_advance => $days_in_advance,
                message_transport_types => \@transport_types
            };

            # Unless a preference for this message name exists, create it
            unless ($preference) {
                my $attr = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Patron::Message::Attributes->find({
                    message_name => $in
                });
                unless ($attr) {
                    Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                        error => "Message type $in not found."
                    );
                }
                $edited_preference->{'message_attribute_id'} =
                        $attr->message_attribute_id;
                if ($borrowernumber) {
                    $edited_preference->{'borrowernumber'}=$found->borrowernumber;
                } else {
                    $edited_preference->{'categorycode'}=$found->categorycode;
                }
                $preference = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Patron::Message::Preference->new(
                    $edited_preference)->store;
            }
            # Otherwise, modify the already-existing one
            else {
                $preference->set($edited_preference)->store;
            }
            $preference->_push_to_action_buffer($actionLog);
        }

        # Finally, return the preferences
        my $preferences = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Patron::Message::Preferences->search({borrowernumber => $borrowernumber});
        $preferences->_log_action_buffer($actionLog, $borrowernumber);

        return $c->render(status => 200, openapi => $preferences);
    }
    catch {
        unless ($found) {
            return $c->render( status => 400, openapi => { error => "Patron or category not found" } );
        }
        if ($_->isa('Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter')) {
            return $c->render( status => 400, openapi => { error => $_->error });
        }
        Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::rethrow_exception($_);
    };
}

=head3 list_checkouts

List Koha::Checkout objects including renewability (for checked out items)
<
=cut

sub list_checkouts {
    my $c = shift->openapi->valid_input or return;

    my $checked_in = $c->validation->param('checked_in');
    my $borrowernumber = $c->validation->param('patron_id');

    try {
        my $patron = Koha::Patrons->find($borrowernumber) || return;

        my $checkouts_set;

        if ( $checked_in ) {
            $checkouts_set = Koha::Old::Checkouts->new;
        } else {
            $checkouts_set = Koha::Checkouts->new;
        }

        my $args = $c->validation->output;
        # Note: enumchron is mapped to serial_issue_number for compatibility with Koha item mapping
        # but also output as is for back-compatibility of the API.
        my $attributes = {
            join => { 'item' => ['biblio', 'biblioitem'] },
            '+select' => [
                'item.itype', 'item.homebranch', 'item.holdingbranch', 'item.ccode', 'item.permanent_location',
                'item.enumchron', 'item.enumchron', 'item.biblionumber', 'item.barcode',
                'biblioitem.itemtype', 'biblioitem.publicationyear',
                'biblio.title', 'biblio.subtitle', 'biblio.part_number', 'biblio.part_name', 'biblio.unititle', 'biblio.copyrightdate'
            ],
            '+as' => [
                'item_itype', 'homebranch', 'holdingbranch', 'ccode', 'permanent_location', 
                'enumchron', 'serial_issue_number', 'biblionumber', 'external_id',
                'biblio_itype', 'publication_year',
                'title', 'subtitle', 'part_number', 'part_name', 'uniform_title', 'copyright_date'
            ]
        };

        # Extract reserved params
        my ( $filtered_params, $reserved_params ) = $c->extract_reserved_params($args);

        # Merge sorting into query attributes
        $c->dbic_merge_sorting(
            {
                attributes => $attributes,
                params     => $reserved_params,
                result_set => $checkouts_set
            }
        );

        # Merge pagination into query attributes
        $c->dbic_merge_pagination(
            {
                filter => $attributes,
                params => $reserved_params
            }
        );

        # Call the to_model function by reference, if defined
        if ( defined $filtered_params ) {
            # remove checked_in
            delete $filtered_params->{checked_in};
            # Apply the mapping function to the passed params
            $filtered_params = $checkouts_set->attributes_from_api($filtered_params);
            $filtered_params = $c->build_query_params( $filtered_params, $reserved_params );
        }

        $filtered_params->{borrowernumber} = $patron->borrowernumber;

        # Perform search
        my $checkouts = $checkouts_set->search( $filtered_params, $attributes );
        my $total     = $checkouts_set->search->count;

        $c->add_pagination_headers(
            {
                total      => ($checkouts->is_paged ? $checkouts->pager->total_entries : $checkouts->count),
                base_total => $checkouts->count,
                params     => $args,
            }
        );

        # TODO: Create Koha::Availability::Renew for checking renewability
        #       via Koha::Availability
        my $patron_blocks = '';
        # Disallow renewal if listing checked-in loans or OpacRenewalAllowed is off
        if ($checked_in || !C4::Context->preference('OpacRenewalAllowed')) {
            $patron_blocks = "NoMoreRenewals";
        } else {
            my $patron_checks = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Patron->new(
                scalar Koha::Patrons->find($borrowernumber)
            );
            if ((my $err = $patron_checks->debt_renew_opac ||
                $patron_checks->debarred || $patron_checks->gonenoaddress ||
                $patron_checks->lost || $patron_checks->expired)
            ) {
                $err = ref($err);
                $err =~ s/Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron:://;
                $patron_blocks = lc($err);
            }
        }
        # END TODO

        my $item_level_itypes = C4::Context->preference('item-level_itypes');

        my @results;
        while (my $checkout = $checkouts->next) {
            # Need to use the unblessed object to access joined fields
            my $checkout_ub = $checkout->unblessed;
            # _GetCircControlBranch takes an item, but we have all the required item
            # fields in $checkout
            my $branchcode   = C4::Circulation::_GetCircControlBranch($checkout_ub, $patron->unblessed);

            my $itype = $item_level_itypes && $checkout_ub->{'item_itype'}
                ? $checkout_ub->{'item_itype'} : $checkout_ub->{'biblio_itype'};
            my $can_renew = 1;
            my $blocks = '';
            if ($patron_blocks) {
                $can_renew = 0;
                $blocks = $patron_blocks;
            } 
            my $circ_rule = Koha::CirculationRules->get_effective_rule(
                {   
                    rule_name    => 'renewalsallowed',
                    categorycode => $patron->categorycode,
                    itemtype     => $itype,
                    branchcode   => $branchcode,
                    ccode        => $checkout_ub->{'ccode'},
                    permanent_location => $checkout_ub->{'permanent_location'}
                }
            );
            my $max_renewals = ($circ_rule && $circ_rule->rule_value ne '') ? 0+$circ_rule->rule_value : undef;

            my $result = $checkout->to_api;
            $result->{'biblio_id'} = $result->{'biblionumber'};
            delete $result->{'biblionumber'};

            $result->{'max_renewals'} = $max_renewals;
            if (!$blocks) {
                ($can_renew, $blocks) = C4::Circulation::CanBookBeRenewed($patron, $checkout);
            }

            $result->{'renewable'} = $can_renew ? Mojo::JSON->true : Mojo::JSON->false;
            $result->{'renewability_blocks'} = $blocks;

            push @results, $result;
        }

        return $c->render( status => 200, openapi => \@results );
    } catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(
                status => 500,
                openapi => { error => $_->{msg} }
            );
        } else {
            return $c->render(
                status => 500,
                openapi => { error => "Something went wrong, check the logs." }
            );
        }
    };
}

sub validate_credentials {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->validation->param('body');
    my $userid = $body->{userid} || $body->{cardnumber};
    my $password = $body->{password};

    unless ($userid) {
        return $c->render( 
            status => 400, 
            openapi => {
                error => "Either userid or cardnumber is required."
            }
        );
    }

    my ($ret) = checkpw( $userid, $password, undef, undef, 1 );
    if (!$ret) {
        return $c->render(
            status => 401, 
            openapi => { error => "Login failed." }
        );
    }

    my $patron = Koha::Patrons->find({ userid => $userid });
    $patron = Koha::Patrons->find({ cardnumber => $userid }) unless $patron;

    if (!$patron) {
        # This should never happen
        return $c->render(
            status => 401, 
            openapi => { error => "Login failed." }
        );
    }

    # Update last login date after retrieving patron so that
    # the previous date is returned:
    track_login_daily($patron->userid);

    if ($patron->lost) {
        return $c->render( 
            status => 403, 
            openapi => { 
                error => "Patron's card has been marked as 'lost'. Access forbidden." 
            }
        );
    }

    return $c->render(status => 200, openapi => $patron->to_api);
}

# Takes a HASHref of parameters
# Returns a HASHref that contains
# 1. not_required HASHref
#       - parameters that do not need librarian confirmation
# 2. required HASHref
#       - parameters that do need librarian confirmation
sub _parameters_require_modification_request {
    my ($body) = @_;

    my $not_required = {
        'privacy' => 1,
        'sms_number' => 1,
        'email' => 1,
    };

    my $params = {
        not_required => {},
        required     => {},
    };
    foreach my $param (keys %$body) {
        if ($not_required->{$param}) {
            $params->{not_required}->{$param} = $body->{$param};
        }
        else {
            $params->{required}->{$param} = $body->{$param};
        }
    }

    return $params;
}

1;
