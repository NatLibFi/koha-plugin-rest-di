package Koha::Plugin::Fi::KohaSuomi::DI::ArticleRequestController;

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

use Koha::ArticleRequest;
use Koha::ArticleRequests;
use Koha::DateUtils;
use Koha::Items;
use Koha::Patrons;

=head1 Koha::Plugin::Fi::KohaSuomi::DI::ArticleRequestController

A class implementing the controller methods for the article requests API

=cut

sub list {
    my $c = shift->openapi->valid_input or return;

    return try {

        my $ar_rs = Koha::ArticleRequests->new;
        my $args = $c->validation->output;
        my $attributes = {};

        # Extract reserved params
        my ( $filtered_params, $reserved_params ) = $c->extract_reserved_params($args);

        # Merge sorting into query attributes
        $c->dbic_merge_sorting(
            {
                attributes => $attributes,
                params     => $reserved_params,
                result_set => $ar_rs
            }
        );

        # Merge pagination into query attributes
        $c->dbic_merge_pagination(
            {
                filter => $attributes,
                params => $reserved_params
            }
        );

        if ( defined $filtered_params ) {
            # Apply the mapping function to the passed params
            $filtered_params = $ar_rs->attributes_from_api($filtered_params);
            $filtered_params = $c->build_query_params( $filtered_params, $reserved_params );
        }

        # By default display only requests that are pending or being processed
        unless ( $filtered_params->{status} ) {
            $filtered_params->{'-or'} = [
                { status => Koha::ArticleRequest::Status::Pending },
                { status => Koha::ArticleRequest::Status::Processing }
            ];
        }

        $filtered_params->{borrowernumber} = $c->validation->param('patron_id');

        my $requests = $ar_rs->search( $filtered_params, $attributes );
        my $total = $ar_rs->search( {borrowernumber => $c->validation->param('patron_id') } )->count;

        $c->add_pagination_headers(
            {
                total      => ($requests->is_paged ? $requests->pager->total_entries : $requests->count),
                base_total => $total,
                params     => $args,
            }
        );

        return $c->render( status => 200, openapi => $requests->to_api );
    }
    catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(
                status  => 500,
                openapi => { error => $_->{msg} }
            );
        }
        else {
            return $c->render(
                status  => 500,
                openapi => { error => "Something went wrong, check the logs." }
            );
        }
    };
}

sub add {
    my $c = shift->openapi->valid_input or return;

    my $body = $c->req->json;

    my $patron_id  = $c->validation->param('patron_id');

    my $biblio_id  = $body->{biblio_id};
    my $library_id = $body->{pickup_library_id};
    my $item_id    = $body->{item_id};
    my $notes      = $body->{notes};
    my $title      = $body->{title};
    my $author     = $body->{author};
    my $volume     = $body->{volume};
    my $issue      = $body->{issue};
    my $date       = $body->{date};
    my $pages      = $body->{pages};
    my $chapters   = $body->{chapters};

    # We set default values for format if it does not come from API request,
    # otherwise Koha almost silently dies with Koha::Exceptions::ArticleRequest::WrongFormat
    # (for a moment of a patch formats was SCAN|PHOTOCOPY, check the pref value below)
    my $formats = C4::Context->multivalue_preference('ArticleRequestsSupportedFormats');
    my $format  = $body->{format} // $formats->[0];

    my $patron = Koha::Patrons->find($patron_id);

    unless ($patron) {
        return $c->render( status  => 404, openapi => {error => "Patron not found"} );
    }

    if (my $problem = _opac_patron_restrictions($c, $patron)) {
        return $c->render(
            status => 403,
            openapi => { error => "Request cannot be placed. Reason: $problem" }
        );
    }

    unless ($biblio_id or $item_id) {
        return $c->render(
            status => 400,
            openapi => { error => "At least one of biblio_id, item_id should be given" }
        );
    }

    if ($item_id) {
        my $item = Koha::Items->find($item_id);
        my $item_biblio_id = $item->biblionumber;
        if ($biblio_id and $biblio_id != $item_biblio_id) {
            return $c->render(
                status => 400,
                openapi => { error => "Item $item_id doesn't belong to biblio $biblio_id" }
            );
        }
        $biblio_id ||= $item_biblio_id;
    }

    my $ar = Koha::ArticleRequest->new(
        {
            borrowernumber => $patron_id,
            biblionumber   => $biblio_id,
            branchcode     => $library_id,
            itemnumber     => $item_id,
            title          => $title,
            author         => $author,
            volume         => $volume,
            issue          => $issue,
            date           => $date,
            pages          => $pages,
            chapters       => $chapters,
            patron_notes   => $notes,
            format         => $format,
        }
    )->store();

    return $c->render( status => 201, openapi => $ar->to_api );
}

sub edit {
    my $c = shift->openapi->valid_input or return;

    my $request_id = $c->validation->param('article_request_id');
    my $request = Koha::ArticleRequests->find($request_id);

    unless ($request && $request->borrowernumber == $c->validation->param('patron_id')) {
        return $c->render(
            status  => 404,
            openapi => { error => "Request not found" }
        );
    }

    my $body = $c->req->json;

    my $library_id = $body->{pickup_library_id};

    $request->branchcode($library_id) if ($library_id);
    $request->store();

    return $c->render( status => 200, openapi => $request->to_api );
}

sub delete {
    my $c = shift->openapi->valid_input or return;

    my $request_id = $c->validation->param('article_request_id');
    my $request = Koha::ArticleRequests->find($request_id);

    unless ($request && $request->borrowernumber == $c->validation->param('patron_id')
        && $request->status ne Koha::ArticleRequest::Status::Canceled
    ) {
        return $c->render(
            status  => 404,
            openapi => { error => "Request not found" }
        );
    }

    if (my $problem = _opac_patron_restrictions($c, $request->borrowernumber)) {
        return $c->render(
            status => 403,
            openapi => { error => "Request cannot be cancelled. Reason: $problem" }
        );
    }

    if (!_can_request_be_canceled_from_opac($request, $request->borrowernumber)) {
        return $c->render(
            status  => 403,
            openapi => { error => "Request cannot be cancelled by patron." }
        );
    }

    $request->cancel();

    return $c->render( status => 200, openapi => {} );
}

# Restrict operations via REST API if patron has some restrictions.
#
# The following reasons can be returned:
#
# 1. debarred
# 2. gonenoaddress
# 3. cardexpired
# 4. maximumholdsreached
# 5. (cardlost, but this is returned via different error message. See KD-2165)
#
sub _opac_patron_restrictions {
    my ($c, $patron) = @_;

    $patron = ref($patron) eq 'Koha::Patron'
                ? $patron
                : Koha::Patrons->find($patron);
    return 0 unless $patron;
    return 0 if (!$c->stash('is_owner_access')
                 && !$c->stash('is_guarantor_access'));
    my @problems = $patron->status_not_ok;
    foreach my $problem (@problems) {
        $problem = ref($problem);
        next if $problem =~ /Debt/;
        next if $problem =~ /Checkout/;
        $problem =~ s/Koha::Exceptions::(.*::)*//;
        return lc($problem);
    }
    return 0;
}

=head2 _can_request_be_canceled_from_opac

    $ok = _can_request_be_canceled_from_opac($request, $borrowernumber);

    returns 1 if request can be cancelled by user from OPAC.
    First check if request belongs to user, next checks if request is not completed

=cut

sub _can_request_be_canceled_from_opac {
    my ($request, $borrowernumber) = @_;

    return unless $request and $borrowernumber;

    return 0 unless $request->borrowernumber == $borrowernumber;
    return 0 if ( $request->status ne 'PENDING' );

    return 1;
}

1;
