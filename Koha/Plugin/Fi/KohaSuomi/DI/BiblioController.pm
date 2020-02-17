package Koha::Plugin::Fi::KohaSuomi::DI::BiblioController;

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

use Koha::AuthorisedValues;
use Koha::Serials;
use Koha::Subscriptions;

=head1 Koha::Plugin::Fi::KohaSuomi::DI::BiblioController

A class implementing the controller methods for the patron-related API

=head2 Class Methods

=head3 get_serial_subscriptions

=cut

sub get_serial_subscriptions {
    my $c = shift->openapi->valid_input or return;

    # Can't use a join here since subscriptions and serials are missing proper relationship in the database.
    my @all_serials;
    my $subscriptions = Koha::Subscriptions->search( 
        { 
            biblionumber => $c->validation->param('biblio_id')
        },
        {
            select => [ qw( subscriptionid biblionumber branchcode location callnumber ) ]
        }
    );
    while (my $subscription = $subscriptions->next()) {
        my $serials = Koha::Serials->search(
            { 
                subscriptionid => $subscription->subscriptionid 
            },
            {
                select => [ qw( serialid serialseq serialseq_x serialseq_y serialseq_z publisheddate publisheddatetext notes ) ],
                '+columns' => {
                    received => \do { "IF(status=2, 1, 0)" }
                }
            }
        );
        if ($serials->count > 0) {
            my $record = {
                subscription_id => $subscription->subscriptionid, 
                biblio_id       => $subscription->biblionumber, 
                library_id      => $subscription->branchcode,
                location        => $subscription->location,
                callnumber      => $subscription->callnumber,
                issues          => $serials->to_api
            };
            if ($subscription->location) {
                my $loc = Koha::AuthorisedValues->search({
                    category => 'LOC',
                    authorised_value => $subscription->location
                })->next;
                $record->{location_description} = $loc->lib if defined $loc;
            }
            push @all_serials, $record;
        }
    }

    return $c->render(status => 200, openapi => { subscriptions => \@all_serials });
}

1;
