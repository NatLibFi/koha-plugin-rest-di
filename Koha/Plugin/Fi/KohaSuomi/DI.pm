package Koha::Plugin::Fi::KohaSuomi::DI;

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

use base qw(Koha::Plugins::Base);

use Mojo::JSON qw(decode_json);

our $VERSION = "{VERSION}";

our $metadata = {
    name            => 'REST API plugin for Koha for discovery interfaces',
    author          => 'Koha-Suomi and The National Library of Finland',
    date_authored   => '2017-02-17',
    date_updated    => '2019-04-10',
    minimum_version => '18.11.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin implements API endpoints required'
                     . ' for the integration of advanced discovery interfaces'
                     . ' with Koha.'
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_dir = $self->mbf_dir();
    return JSON::Validator->new->schema($spec_dir . "/openapi.json")->schema->{data};
}

sub api_namespace {
    my ( $self ) = @_;
    
    return 'kohasuomi';
}

1;