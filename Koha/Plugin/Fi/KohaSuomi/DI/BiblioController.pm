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

A class implementing the controller methods for the biblio-related API

=head2 Class Methods

=head3 get_holdings

=cut

sub get_holdings {
    my $c = shift->openapi->valid_input or return;
 
    my $schema = Koha::Database->new()->schema();
    my @holdings = $schema->resultset('Holding')->search(
        { 'biblionumber' => $c->validation->param('biblio_id'), 'me.deleted_on' => undef },
        {
            join         => 'holdings_metadatas',
            '+columns'   => [ qw/ holdings_metadatas.format holdings_metadatas.schema holdings_metadatas.metadata / ],
            result_class => 'DBIx::Class::ResultClass::HashRefInflator'
        }
    );

    # Better field names and additional information
    for my $holding (@holdings) {
        $holding->{metadata} = delete $holding->{holdings_metadatas};
        $holding->{collection_code} = delete $holding->{ccode};
        $holding->{create_date} = delete $holding->{datecreated};
        $holding->{holding_library_id} = delete $holding->{holdingbranch};
        $holding->{suppressed} = delete $holding->{suppress};

        if ($holding->{ccode}) {
            my $ccode = Koha::AuthorisedValues->search({
                category => 'CCODE',
                authorised_value => $holding->{ccode}
            })->next;
            $holding->{ccode_description} = $ccode->lib if defined $ccode;
        }
        if ($holding->{location}) {
            my $loc = Koha::AuthorisedValues->search({
                category => 'LOC',
                authorised_value => $holding->{location}
            })->next;
            $holding->{location_description} = $loc->lib if defined $loc;
        }
    }

    return $c->render(status => 200, openapi => { holdings => \@holdings });
}

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
