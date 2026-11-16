package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Biblio::Availability;

# Copyright 2016 Koha-Suomi Oy
# Copyright 2019 University of Helsinki (The National Library Of Finland)
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use Scalar::Util qw(looks_like_number);
use Mojo::JSON;

use base qw(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability);

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron;

=head1 NAME

Koha::Biblio::Availability - Koha Biblio Availability object class

=head1 SYNOPSIS

Parent class for different types of biblio availabilities.

=head1 DESCRIPTION

=head2 Class Methods

This class is for storing biblio availability information. It is a subclass of
Koha::Availability. For more documentation on usage, see Koha::Availability.

=cut

=head3 new

my $availability = Koha::Biblio::Availability->new({
    biblionumber => 123
});

REQUIRED PARAMETERS:
    biblio (Koha::Biblio) / biblionumber

OPTIONAL PARAMETERS:
    patron (Koha::Patron) / borrowernumber

Creates a new Koha::Biblio::Availability object.

=cut

sub new {
    my $class = shift;
    my ($params) = @_;
    my $self = $class->SUPER::new(@_);

    $self->{'biblio'} = undef;
    $self->{'patron'} = undef;

    # ARRAYref of Koha::Item::Availability objects
    # ...for available items
    $self->{'item_availabilities'} = [];
    # ...for unavailable items
    $self->{'item_unavailabilities'} = [];

    # Optionally include found holds in hold queue length calculation.
    $self->{'include_found_in_hold_queue'} = $params->{'include_found_in_hold_queue'};

    # Optionally include suspended holds in hold queue length calculation.
    $self->{'include_suspended_in_hold_queue'} = $params->{'include_suspended_in_hold_queue'};

    if (exists $params->{'biblio'}) {
        unless (ref($params->{'biblio'}) eq 'Koha::Biblio') {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                error => 'Parameter must be a Koha::Biblio object.',
                parameter => 'biblio',
            );
        }
        $self->biblio($params->{'biblio'});
    } elsif (exists $params->{'biblionumber'}) {
        unless (looks_like_number($params->{'biblionumber'})) {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                error => 'Parameter must be a numeric value.',
                parameter => 'biblionumber',
            );
        }
        my $biblio = Koha::Biblios->find($params->{'biblionumber'});
        $self->biblio($biblio);
        unless ($self->biblio) {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::NotFound->throw(
                error => 'Biblio not found.',
                biblionumber => $params->{'biblionumber'},
            );
        }
    } else {
        Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::MissingParameter->throw(
            error => "Missing one of parameters 'biblionumber, 'biblio'.",
            parameter => ["biblionumber", "biblio"],
        );
    }

    if (exists $params->{'patron'}) {
        unless (ref($params->{'patron'}) eq 'Koha::Patron') {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                error => 'Parameter must be a Koha::Patron object.',
                parameter => 'patron',
            ) if $params->{'patron'};
        }
        $self->patron($params->{'patron'});
    } elsif (exists $params->{'borrowernumber'}) {
        unless (looks_like_number($params->{'borrowernumber'})) {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                error => 'Parameter must be a numeric value.',
                parameter => 'borrowernumber',
            );
        }
        my $patron = Koha::Patrons->find($params->{'borrowernumber'});
        $self->patron($patron);
        unless ($self->patron) {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::NotFound->throw(
                error => 'Patron not found.',
                borrowernumber => $params->{'borrowernumber'},
            );
        }
    }

    return $self;
}

=head3 to_api

Returns a HASHref that contains availability information.

Numifies numbers for API to be numbers instead of strings.

=cut

sub to_api {
    my ($self) = @_;

    my $item_availabilities = [];
    foreach my $item_availability (@{$self->item_availabilities}) {
        push @{$item_availabilities}, $item_availability->to_api;
    }
    foreach my $item_availability (@{$self->item_unavailabilities}) {
        push @{$item_availabilities}, $item_availability->to_api;
    }
    my $confirmations = $self->SUPER::to_api_exception($self->confirmations);
    my $notes = $self->SUPER::to_api_exception($self->notes);
    my $unavailabilities = $self->SUPER::to_api_exception($self->unavailabilities);
    my $availability = {
        available => $self->available
                         ? Mojo::JSON->true
                         : Mojo::JSON->false,
    };
    if (keys %{$confirmations} > 0) {
        $availability->{'confirmations'} = $confirmations;
    }
    if (keys %{$notes} > 0) {
        $availability->{'notes'} = $notes;
    }
    if (keys %{$unavailabilities} > 0) {
        $availability->{'unavailabilities'} = $unavailabilities;
    }

    my $hash = {
        biblionumber => 0+$self->biblio->biblionumber,
        availability => $availability,
        item_availabilities => $item_availabilities,
    };
    if (defined $self->{'hold_queue_length'}) {
        $hash->{'hold_queue_length'} = 0+$self->{'hold_queue_length'};
    }
    if (defined $self->{'items_total'}) {
        $hash->{'items_total'} = 0+$self->{'items_total'};
    }
    if (defined $self->{'items_checked'}) {
        $hash->{'items_checked'} = 0+$self->{'items_checked'};
    }
    return $hash;
}

=head3 get_hold_queue_length

Get hold queue length for the biblio

=cut

sub get_hold_queue_length
{
    my ($self) = @_;

    my $hold_params = {
        biblionumber => $self->biblio->biblionumber,
    };
    if (!$self->{'include_found_in_hold_queue'}) {
        $hold_params->{found} = undef;
    }
    if (!$self->{'include_suspended_in_hold_queue'}) {
        $hold_params->{suspend} = 0;
    }
    return Koha::Holds->search($hold_params)->count;
}

1;
