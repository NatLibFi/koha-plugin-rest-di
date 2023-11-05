package Koha::Plugin::Fi::KohaSuomi::DI::CourseReservesController;

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

use Koha::AuthorisedValues;
use Koha::Course::Reserves;
use Koha::Courses;
use Koha::Patrons;

=head1 Koha::Plugin::Fi::KohaSuomi::DI::CourseReservesController

A class implementing the controller methods for the course reserves API

=head2 Class Methods

=head3 getCourses

Get courses

=cut

sub getCourses {
    my $c = shift->openapi->valid_input or return;

    my $attributes = {
        where => {
            enabled => 'yes'
        }
    };
    return _get_paged_results($c, Koha::Courses->new, $attributes);
}

sub getDepartments {
    my $c = shift->openapi->valid_input or return;

    my $courses = Koha::Database->new()->schema()->resultset('Course')->search(
        { department => { '!=', undef }, enabled => 'yes' },
        { select => 'department' }
    );
    my $attributes = {
        where => {
            category => 'DEPARTMENT',
            authorised_value => { '-in' => $courses->as_query }
        }
    };
    return _get_paged_results($c, Koha::AuthorisedValues->new, $attributes);
}

sub getInstructors {
    my $c = shift->openapi->valid_input or return;

    my $attributes = {
        join => {
            course_instructors => 'course',
        },
        where => {
            'course_instructors.course_id' => { '!=' => undef },
            'course.enabled' => 'yes'
        }
    };
    return _get_paged_results($c, Koha::Patrons->new, $attributes);
}

sub getCourseReserves {
    my $c = shift->openapi->valid_input or return;

    my $attributes = {
        join => [ { course => 'course_instructors' }, { ci => 'itemnumber' } ],
        '+select' => [ qw/ course.course_name course.department course_instructors.borrowernumber itemnumber.biblionumber / ],
        '+as' => [ qw/ course_name course_department patron_id biblio_id / ],
        where => {
            'course.enabled' => 'yes'
        }
    };
    return _get_paged_results($c, Koha::Course::Reserves->new, $attributes);
}

sub _get_paged_results
{
    my ($c, $result_set, $attributes) = @_;

    return try {
        # Extract reserved params
        my $args = $c->validation->output;
        my ( $filtered_params, $reserved_params ) = $c->extract_reserved_params($args);
        $attributes //= {};

        # Merge sorting into query attributes
        $c->dbic_merge_sorting(
            {
                attributes => $attributes,
                params     => $reserved_params,
                result_set => $result_set
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
            $filtered_params = $result_set->attributes_from_api($filtered_params);
            $filtered_params = $c->build_query_params( $filtered_params, $reserved_params );
            # course_id might be in joined tables as well, so prefix with 'me.'
            if (exists $filtered_params->{course_id}) {
                $filtered_params->{'me.course_id'} = $filtered_params->{course_id};
                delete $filtered_params->{course_id};
            }
            # Map patron_id to borrowernumber
            if (exists $filtered_params->{patron_id}) {
                $filtered_params->{'borrowernumber'} = $filtered_params->{patron_id};
                delete $filtered_params->{patron_id};
            }

        }

        # Perform search
        my $results = $result_set->search($filtered_params, $attributes);
        my $total   = $result_set->search({}, $attributes)->count;

        $c->add_pagination_headers({
            total => ($results->is_paged ? $results->pager->total_entries : $results->count),
            base_total => $total,
            params => $args,
        });

        return $c->render(status => 200, openapi => $results->to_api());
    } catch {
        if ( $_->isa('DBIx::Class::Exception') ) {
            return $c->render(status => 500, openapi => { error => $_->msg });
        }
        else {
            return $c->render(
                status => 500,
                openapi => { error => "Something went wrong, check the logs." }
            );
        }
    };
}

1;