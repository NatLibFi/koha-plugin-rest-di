package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability;

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

use base qw(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability);

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron;

use Koha::Item;

=head1 NAME

Koha::Item::Availability - Koha Item Availability object class

=head1 SYNOPSIS

Parent class for different types of item availabilities.

=head1 DESCRIPTION

=head2 Class Methods

This class is for storing item availability information. It is a subclass of
Koha::Availability. For more documentation on usage, see Koha::Availability.

=cut

=head3 new

my $availability = Koha::Item::Availability->new({
    itemnumber => 123
});

REQUIRED PARAMETERS:
    item (Koha::Item) / itemnumber

OPTIONAL PARAMETERS:
    patron (Koha::Patron) / borrowernumber

Creates a new Koha::Item::Availability object.

=cut

sub new {
    my $class = shift;
    my ($params) = @_;
    my $self = $class->SUPER::new(@_);

    $self->{'item'} = undef;
    $self->{'patron'} = undef;

    # Optionally include found holds in hold queue length calculation.
    $self->{'include_found_in_hold_queue'} = $params->{'include_found_in_hold_queue'};

    # Optionally include suspended holds in hold queue length calculation.
    $self->{'include_suspended_in_hold_queue'} = $params->{'include_suspended_in_hold_queue'};

    if (exists $params->{'item'}) {
        unless (ref($params->{'item'}) eq 'Koha::Item') {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                error => 'Parameter must be a Koha::Item object.',
                parameter => 'item',
            );
        }
        $self->item($params->{'item'});
    } elsif (exists $params->{'itemnumber'}) {
        unless (looks_like_number($params->{'itemnumber'})) {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                error => 'Parameter must be a numeric value.',
                parameter => 'itemnumber',
            );
        }
        my $item = Koha::Items->find($params->{'itemnumber'});
        $self->item($item);
        unless ($self->item) {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::NotFound->throw(
                error => 'Item not found.',
                itemnumber => $params->{'itemnumber'},
            );
        }
    } else {
        Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::MissingParameter->throw(
            error => "Missing one of parameters 'itemnumber, 'item'.",
            parameter => ["itemnumber", "item"],
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

Returns a HASHref that contains item availability information.

Numifies numbers for API to be numbers instead of strings.

=cut

sub to_api {
    my ($self) = @_;

    my $confirmations = $self->SUPER::to_api_exception($self->confirmations);
    my $notes = $self->SUPER::to_api_exception($self->notes);
    my $unavailabilities = $self->SUPER::to_api_exception($self->unavailabilities);
    my $item = $self->item;
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
        # Don't reveal borrowernumber through REST API.
        foreach my $key (keys %{$unavailabilities}) {
            delete $unavailabilities->{$key}{'borrowernumber'};
        }

        $availability->{'unavailabilities'} = $unavailabilities;
    }

    my $ccode_desc = Koha::AuthorisedValues->search({
        category => 'CCODE',
        authorised_value => $item->ccode
    })->next;
    my $loc_desc = Koha::AuthorisedValues->search({
        category => 'LOC',
        authorised_value => $item->location
    })->next;
    $ccode_desc = $ccode_desc->lib if defined $ccode_desc;
    $loc_desc   = $loc_desc->lib if defined $loc_desc;
    my $hash = $item->to_api;
    $hash->{'availability'} = $availability;
    $hash->{'hold_queue_length'} = $self->get_hold_queue_length();
    $hash->{'collection_code_description'} = $ccode_desc;
    $hash->{'location_description'} = $loc_desc;
    return $hash;
}

=head3 get_hold_queue_length

Get hold queue length for the item

=cut

sub get_hold_queue_length
{
    my ($self) = @_;

    my $hold_params = {
        itemnumber => $self->item->itemnumber,
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
