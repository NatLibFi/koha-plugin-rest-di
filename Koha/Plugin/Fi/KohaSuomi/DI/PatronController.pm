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

use C4::Auth qw( haspermission );

use Koha::Biblios;

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Patron;

=head1 Koha::Plugin::Fi::KohaSuomi::DI::PatronController

A class implementing the controller methods for the patron-related API

=head2 Class Methods

=head3 get_status

Get borrower's status

=cut

sub get_status {
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
        my $attributes = {
            join => { 'item' => ['biblio', 'biblioitem'] },
            '+select' => [
                'item.itype', 'item.homebranch', 'item.holdingbranch', 'item.ccode', 'item.permanent_location',
                'item.enumchron', 'item.biblionumber', 'item.barcode',
                'biblioitem.itemtype', 'biblioitem.publicationyear',
                'biblio.title', 'biblio.subtitle', 'biblio.part_number', 'biblio.part_name', 'biblio.unititle', 'biblio.copyrightdate'
            ],
            '+as' => [
                'item_itype', 'homebranch', 'holdingbranch', 'ccode', 'permanent_location', 
                'enumchron', 'biblionumber', 'external_id',
                'biblio_itype', 'publication_year',
                'title', 'subtitle', 'part_number', 'part_name', 'uniform_title', 'copyright_date'
            ]
        };

        # Extract reserved params
        my ( $filtered_params, $reserved_params ) = $c->extract_reserved_params($args);

        $filtered_params->{borrowernumber} = $patron->borrowernumber;

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

        # Perform search
        my $checkouts = $checkouts_set->search( $filtered_params, $attributes );

        if ($checkouts->is_paged) {
            $c->add_pagination_headers({
                total => $checkouts->pager->total_entries,
                params => $args,
            });
        }

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
            my $max_renewals = 0;
            my $blocks = '';
            if ($patron_blocks) {
                $can_renew = 0;
                $blocks = $patron_blocks;
            } else {
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
                $max_renewals = ($circ_rule && $circ_rule->rule_value ne '') ? 0+$circ_rule->rule_value : undef;
            }

            my $result = $checkout->to_api;
            $result->{'biblio_id'} = $result->{'biblionumber'};
            delete $result->{'biblionumber'};

            $result->{'max_renewals'} = $max_renewals;
            if (!$blocks) {
                ($can_renew, $blocks) = C4::Circulation::CanBookBeRenewed(
                    $patron->borrowernumber, $checkout->itemnumber
                );
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

    my $dbh = C4::Context->dbh;
    unless (C4::Auth::checkpw_internal($dbh, $userid, $password)) {
        return $c->render(
            status => 401, 
            openapi => { error => "Login failed." }
        );
    }

    my $patron = Koha::Patrons->find({ userid => $userid });
    $patron = Koha::Patrons->find({ cardnumber => $userid }) unless $patron;

    if ($patron && $patron->lost) {
        return $c->render( 
            status => 403, 
            openapi => { 
                error => "Patron's card has been marked as 'lost'. Access forbidden." 
            }
        );
    }

    return $c->render(status => 200, openapi => $patron->to_api);
}

1;
