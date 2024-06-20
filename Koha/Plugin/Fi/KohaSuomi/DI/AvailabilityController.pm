package Koha::Plugin::Fi::KohaSuomi::DI::AvailabilityController;

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

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::ArticleRequest;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checkout;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Hold;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Search;


=head1 Koha::Plugin::Fi::KohaSuomi::DI::AvailabilityController

A class implementing the controller methods for the availability-related API

=head2 Class Methods

=head3

=cut

sub biblio_article_request {
    my $c = shift->openapi->valid_input or return;

    my @availabilities;
    my $user = $c->stash('koha.user');
    my $borrowernumber = $c->validation->param('patron_id');
    my $to_branch = $c->validation->param('library_id');
    my $limit_items = $c->validation->param('limit_items');

    return try {
        my $patron = Koha::Patrons->find($borrowernumber);

        my $biblionumber = $c->validation->output->{'biblio_id'};
        my $params = {
            patron => $patron,
        };

        $params->{'to_branch'} = $to_branch if $to_branch;
        $params->{'limit'} = $limit_items if $limit_items;

        my $availability = undef;
        if (my $biblio = Koha::Biblios->find($biblionumber)) {
            $params->{'biblio'} = $biblio;
            $availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::ArticleRequest->biblio($params);
            return $c->render(status => 200, openapi => $availability->in_opac->to_api);
        }

        return $c->render(
            status  => 404,
            openapi => {error => 'Biblio not found'}
        );
    }
    catch {
        if ($_->isa('Koha::Exceptions::AuthenticationRequired')) {
            return $c->render(status => 401, openapi => { error => "Authentication required." });
        }
        elsif ($_->isa('Koha::Exceptions::NoPermission')) {
            return $c->render(status => 403, openapi => {
                error => "Authorization failure. Missing required permission(s).",
                required_permissions => $_->required_permissions} );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub biblio_hold {
    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');
    my $biblionumber = $c->validation->output->{'biblio_id'};
    my $borrowernumber = $c->validation->param('patron_id');
    my $to_branch = $c->validation->param('library_id');
    my $query_pickup_locations = $c->validation->param('query_pickup_locations');
    my $ignore_patron_holds = $c->validation->param('ignore_patron_holds');
    my $limit_items = $c->validation->param('limit_items');
    my $include_found_in_hold_queue = $c->validation->param('include_found_in_hold_queue');
    my $include_suspended_in_hold_queue = $c->validation->param('include_suspended_in_hold_queue');

    return try {
        my $patron = Koha::Patrons->find($borrowernumber);

        my $params = {
            patron => $patron,
        };

        $params->{'query_pickup_locations'} = 1 if $query_pickup_locations;
        $params->{'ignore_patron_holds'} = 1 if $ignore_patron_holds;
        $params->{'include_found_in_hold_queue'} = 1 if $include_found_in_hold_queue;
        $params->{'include_suspended_in_hold_queue'} = 1 if $include_suspended_in_hold_queue;
        $params->{'to_branch'} = $to_branch if $to_branch;
        $params->{'limit'} = $limit_items if $limit_items;

        my $availability = undef;
        if (my $biblio = Koha::Biblios->find($biblionumber)) {
            $params->{'biblio'} = $biblio;
            $availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Hold->biblio($params);

            return $c->render(status => 200, openapi => $availability->in_opac->to_api);
        }

        return $c->render(
            status  => 404,
            openapi => {error => 'Biblio not found'}
        );
    }
    catch {
        if ($_->isa('Koha::Exceptions::AuthenticationRequired')) {
            return $c->render(status => 401, openapi => { error => "Authentication required." });
        }
        elsif ($_->isa('Koha::Exceptions::NoPermission')) {
            return $c->render(status => 403, openapi => {
                error => "Authorization failure. Missing required permission(s).",
                required_permissions => $_->required_permissions} );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub biblio_search {
    my $c = shift->openapi->valid_input or return;

    my $biblionumber = $c->validation->param('biblio_id');
    my $include_found_in_hold_queue = $c->validation->param('include_found_in_hold_queue');
    my $include_suspended_in_hold_queue = $c->validation->param('include_suspended_in_hold_queue');

    return try {
        my $availability = undef;
        if (my $biblio = Koha::Biblios->find($biblionumber)) {
            my $params = {
                biblio => $biblio,
            };
            $params->{'include_found_in_hold_queue'} = 1 if $include_found_in_hold_queue;
            $params->{'include_suspended_in_hold_queue'} = 1 if $include_suspended_in_hold_queue;
            $availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Search->biblio($params);
            return $c->render(status => 200, openapi => $availability->in_opac->to_api);
        }

        return $c->render(
            status  => 404,
            openapi => {error => 'Biblio not found'}
        );
    }
    catch {
        Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::rethrow_exception($_);
    };
}

sub item_article_request {
    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');
    my $borrowernumber = $c->validation->param('patron_id');
    my $to_branch = $c->validation->param('library_id');

    return try {
        my $patron = Koha::Patrons->find($borrowernumber);

        my $itemnumber = $c->validation->output->{'item_id'};
        my $params = {
            patron => $patron,
        };
        if ($to_branch) {
            $params->{'to_branch'} = $to_branch;
        }
        my $availability = undef;
        if (my $item = Koha::Items->find($itemnumber)) {
            $params->{'item'} = $item;
            $availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::ArticleRequest->item($params);

            return $c->render(status => 200, openapi => $availability->in_opac->to_api);
        }

        return $c->render(
            status  => 404,
            openapi => {error => 'Item not found'}
        );
    }
    catch {
        if ($_->isa('Koha::Exceptions::AuthenticationRequired')) {
            return $c->render(status => 401, openapi => { error => "Authentication required." });
        }
        elsif ($_->isa('Koha::Exceptions::NoPermission')) {
            return $c->render(status => 403, openapi => {
                error => "Authorization failure. Missing required permission(s).",
                required_permissions => $_->required_permissions} );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub item_checkout {
    my $c = shift->openapi->valid_input or return;

    my $user = $c->stash('koha.user');
    my $borrowernumber = $c->validation->param('patron_id');
    my $to_branch = $c->validation->param('library_id');

    return try {
        my $patron = Koha::Patrons->find($borrowernumber);

        my $itemnumber = $c->validation->output->{'item_id'};
        my $params = {
            patron => $patron,
        };
        if ($to_branch) {
            $params->{'to_branch'} = $to_branch;
        }
        my $availability = undef;
        if (my $item = Koha::Items->find($itemnumber)) {
            $params->{'item'} = $item;
            $availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checkout->item($params);

            return $c->render(status => 200, openapi => $availability->in_intranet->to_api);
        }

        return $c->render(
            status  => 404,
            openapi => {error => 'Item not found'}
        );
    }
    catch {
        if ($_->isa('Koha::Exceptions::AuthenticationRequired')) {
            return $c->render(status => 401, openapi => { error => "Authentication required." });
        }
        elsif ($_->isa('Koha::Exceptions::NoPermission')) {
            return $c->render(status => 403, openapi => {
                error => "Authorization failure. Missing required permission(s).",
                required_permissions => $_->required_permissions} );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

sub item_hold {
    my $c = shift->openapi->valid_input or return;

    my @availabilities;
    my $user = $c->stash('koha.user');
    my $borrowernumber = $c->validation->param('patron_id');
    my $query_pickup_locations = $c->validation->param('query_pickup_locations');
    my $to_branch = $c->validation->param('library_id');
    my $include_found_in_hold_queue = $c->validation->param('include_found_in_hold_queue');
    my $include_suspended_in_hold_queue = $c->validation->param('include_suspended_in_hold_queue');

    return try {
        my $patron = Koha::Patrons->find($borrowernumber);

        my $itemnumber = $c->validation->output->{'item_id'};
        my $params = {
            patron => $patron,
        };
        if ($query_pickup_locations) {
            $params->{'query_pickup_locations'} = 1;
        }
        if ($to_branch) {
            $params->{'to_branch'} = $to_branch;
        }
        $params->{'include_found_in_hold_queue'} = 1 if $include_found_in_hold_queue;
        $params->{'include_suspended_in_hold_queue'} = 1 if $include_suspended_in_hold_queue;

        my $availability = undef;
        if (my $item = Koha::Items->find($itemnumber)) {
            $params->{'item'} = $item;
            $availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Hold->item($params);

            return $c->render(status => 200, openapi => $availability->in_opac->to_api);
        }

        return $c->render(
            status  => 404,
            openapi => {error => 'Item not found'}
        );
    }
    catch {
        if ($_->isa('Koha::Exceptions::AuthenticationRequired')) {
            return $c->render(status => 401, openapi => { error => "Authentication required." });
        }
        elsif ($_->isa('Koha::Exceptions::NoPermission')) {
            return $c->render(status => 403, openapi => {
                error => "Authorization failure. Missing required permission(s).",
                required_permissions => $_->required_permissions} );
        }
        Koha::Exceptions::rethrow_exception($_);
    };
}

1;
