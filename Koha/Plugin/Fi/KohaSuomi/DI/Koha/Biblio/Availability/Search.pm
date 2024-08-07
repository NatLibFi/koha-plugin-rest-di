package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Biblio::Availability::Search;

# Copyright 2016 Koha-Suomi Oy
# Copyright 2019 University of Helsinki (The National Library Of Finland)
#
# This file is part of Koha
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use base qw(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Biblio::Availability);

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability::Search;

=head1 NAME

Koha::Biblio::Availability::Search - Koha Biblio Availability Search object class

=head1 SYNOPSIS

my $searchability = Koha::Biblio::Availability::Search->new({
    biblio => $biblio,      # which biblio this availability is for
})

=head1 DESCRIPTION

Class for checking biblio search availability.

This class contains subroutines to determine biblio's availability for search
result in different contexts.

=head2 Class Methods

=cut

=head3 new

Constructs an biblio search availability object. Biblio is always required.

MANDATORY PARAMETERS

    biblio (or biblionumber)

Biblio is a Koha::Biblio -object.

OPTIONAL PARAMETERS

Returns a Koha::Biblio::Availability::Search -object.

=cut

sub new {
    my ($class, $params) = @_;

    my $self = $class->SUPER::new($params);

    # Check only first n items.
    $self->{'limit'} = $params->{'limit'};

    # Check items starting at offset of n.
    $self->{'offset'} = $params->{'offset'};

    return $self;
}

sub in_opac {
    my ($self, $params) = @_;

    $self->reset;

    # Item looper
    $self->_item_looper($params);

    return $self;
}

sub _item_looper {
    my ($self, $params) = @_;

    my @items = $self->biblio->items->as_list;
    my @hostitemnumbers = C4::Items::get_hostitemnumbers_of($self->biblio->biblionumber);
    @hostitemnumbers = grep defined, @hostitemnumbers;
    if (@hostitemnumbers) {
        my @hostitems = Koha::Items->search({
            itemnumber => { 'in' => @hostitemnumbers }
        })->as_list;
        push @items, @hostitems;
    }

    if (scalar(@items) == 0) {
        $self->unavailable(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::NoAvailableItems->new);
        $self->{'items_total'} = 0;
        return;
    }

    # Sort items for paging
    sort { $a->itemnumber <=> $b->itemnumber } @items;
 
    my $opachiddenitems_rules = C4::Context->yaml_preference('OpacHiddenItems');

    my $avoid_queries_after = $params->{'MaxSearchResultsItemsPerRecordStatusCheck'}
        ? C4::Context->preference('MaxSearchResultsItemsPerRecordStatusCheck') : undef;
    my $count = 0;
    my $checked = 0;

    $self->{'hold_queue_length'} = $self->get_hold_queue_length();

    foreach my $item (@items) {
        next if ($item->hidden_in_opac({ rules => $opachiddenitems_rules }));

        $count++;
        # Skip this item if we haven't reached the offset yet
        next if (defined $self->offset && $count <= $self->offset);

        # Skip this item if we have reached the limit. We still need to
        # loop all items for total count of items visible in opac.
        next if (defined $self->limit && $checked >= $self->limit);

        $checked++;

        my $item_availability = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability::Search->new({
            item => $item,
        });
        if ($params->{'MaxSearchResultsItemsPerRecordStatusCheck'} &&
            $count > $avoid_queries_after) {
            # A couple heuristics to limit how many times
            # we query the database for item transfer information, sacrificing
            # accuracy in some cases for speed;
            #
            # 1. don't query if item has one of the other statuses (done inside
            #    item availability calculation)
            # 2. don't check holds status if ignore_holds parameter is given
            # 3. don't check transfer status if ignore_transfer parameter is given
            $params->{'ignore_holds'} = 1;
            $params->{'ignore_transfer'} = 1;
        }

        $item_availability = $item_availability->in_opac($params);
        my $unavails = $item_availability->unavailabilities;
        if ($item_availability->available) {
            push @{$self->{'item_availabilities'}}, $item_availability;
        } else {
            push @{$self->{'item_unavailabilities'}}, $item_availability;
        }
    }

    # After going through items, if none are found available, set the biblio
    # unavailable
    if (@{$self->{'item_availabilities'}} == 0) {
        $self->unavailable(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::NoAvailableItems->new);
    }

    # Add total and checked item count
    $self->{'items_total'} = $count;
    $self->{'items_checked'} = $checked;

    return $self;
}

1;
