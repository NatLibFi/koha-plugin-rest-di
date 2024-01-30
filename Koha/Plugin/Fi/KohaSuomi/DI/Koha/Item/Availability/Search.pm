package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability::Search;

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
use C4::Context;

use base qw(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability);

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Item;

sub new {
    my ($class, $params) = @_;

    my $self = $class->SUPER::new($params);

    return $self;
}

sub in_opac {
    my ($self, $params) = @_;
    my $reason;

    $self->reset;

    my $item = $self->item;

    my $itemcalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Item->new($item);
    $self->unavailable($reason) if $reason = $itemcalc->lost;
    $self->unavailable($reason) if $reason = $itemcalc->damaged;
    $self->unavailable($reason) if $reason = $itemcalc->from_another_library;
    $self->unavailable($reason) if $reason = $itemcalc->notforloan;
    $self->unavailable($reason) if $reason = $itemcalc->restricted;
    $self->unavailable($reason) if $reason = $itemcalc->unknown_barcode;
    $self->unavailable($reason) if $reason = $itemcalc->withdrawn;
    if ($itemcalc->onloan) {
        $self->unavailable($reason) if $reason = $itemcalc->checked_out;
    }

    if (!$params->{'ignore_holds'}) {
        $self->unavailable($reason) if $reason = $itemcalc->held;
    }
    if (!$params->{'ignore_transfer'}) {
        $self->unavailable($reason) if $reason = $itemcalc->transfer;
    }
    if (C4::Context->preference('UseRecalls')) {
        $self->unavailable($reason) if $reason = $itemcalc->recalled;
    }

    return $self;
}

1;
