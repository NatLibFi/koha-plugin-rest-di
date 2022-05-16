package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability::Hold;

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

use base qw(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Item::Availability);

use Koha::Items;
use Koha::Patrons;

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Biblio;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Biblioitem;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::CirculationRule;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Item;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::LibraryItemRule;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Patron;

=head1 NAME

Koha::Item::Availability::Hold - Koha Item Availability Hold object class

=head1 SYNOPSIS

my $holdability = Koha::Item::Availability::Hold->new({
    item => $item,               # which item this availability is for
    patron => $patron,           # check item availability for this patron
})

=head1 DESCRIPTION

Class for checking item hold availability.

This class contains different levels of "recipes" that determine whether or not
an item should be considered available.

=head2 Class Methods

=cut

=head3 new

Constructs an item hold availability object. Item is always required. Patron is
required if patron related checks are needed.

MANDATORY PARAMETERS

    item (or itemnumber)

Item is a Koha::Item -object.

OPTIONAL PARAMETERS

    patron (or borrowernumber)
    to_branch

Patron is a Koha::Patron -object. To_branch is a branchcode of pickup library.

Returns a Koha::Item::Availability::Hold -object.

=cut

sub new {
    my ($class, $params) = @_;

    my $self = $class->SUPER::new($params);

    # Optionally, query ALL possible transfer limits for every item in order
    # to generate a list of available pickup locations.
    # Don't provide the following parameter if you want to skip this step.
    $self->{'query_pickup_locations'} = $params->{'query_pickup_locations'};
    $self->{'pickup_locations'} = [];
    # Additionally, consider any transfer limits to pickup library by
    # providing to_branch parameter with branchcode of pickup library
    $self->{'to_branch'} = $params->{'to_branch'};

    return $self;
}

sub in_opac {
    my ($self) = @_;
    my $reason;

    $self->reset;

    my $item = $self->item;
    my $patron = $self->patron;

    # Check if holds are allowed in OPAC
    if (!C4::Context->preference('OPACHoldRequests')) {
        $self->unavailable(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedInOPAC->new);
        return $self;
    }

    $self->common_biblio_checks;
    $self->common_biblioitem_checks;
    $self->common_issuing_rule_checks;
    my $cache = {};
    $self->common_item_checks({'context_cache' => $cache});
    $self->common_library_item_rule_checks;
    $self->common_patron_checks;
    $self->opac_specific_issuing_rule_checks;

    return $self;
}

=head3 common_biblio_checks

Common checks for both OPAC and intranet.

=cut

sub common_biblio_checks {
    my ($self, $biblio) = @_;
    my $reason;

    unless ($biblio) {
        $biblio = Koha::Biblios->find($self->item->biblionumber);
    }

    my $bibcalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Biblio->new($biblio);

    return $self unless $self->patron;

    if ($reason = $bibcalc->forbid_holds_on_patrons_possessions($self->patron)) {
        $self->unavailable($reason);
    }

    return $self;
}

=head3 common_biblioitem_checks

Common checks for both OPAC and intranet.

=cut

sub common_biblioitem_checks {
    my ($self, $bibitem) = @_;
    my $reason;

    unless ($bibitem) {
        $bibitem = Koha::Biblioitems->find($self->item->biblioitemnumber);
    }

    my $bibitemcalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Biblioitem->new($bibitem);

    return $self unless $self->patron;

    if ($reason = $bibitemcalc->age_restricted($self->patron)) {
        $self->unavailable($reason);
    }

    return $self;
}

=head3 common_issuing_rule_checks

Common checks for both OPAC and intranet.

=cut

sub common_issuing_rule_checks {
    my ($self, $params) = @_;
    my $reason;

    my $item = $self->item;
    my $patron = $self->patron;
    my $branchcode = $params->{'branchcode'} ? $params->{'branchcode'}
                : $self->_get_reservescontrol_branchcode($item, $patron);
    my $args = {
        item => $item,
        branchcode => $branchcode,
        use_cache => $params->{'use_cache'},
    };
    $args->{patron} = $patron if $patron;
    my $holdrulecalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::CirculationRule->new($args);

    if ($reason = $holdrulecalc->zero_holds_allowed) {
        $self->unavailable($reason);
    } else {
        return $self unless $self->patron;

        if ($reason = $holdrulecalc->maximum_holds_reached) {
            $self->unavailable($reason);
        }
        if ($reason = $holdrulecalc->maximum_holds_for_record_reached($params)) {
            $self->unavailable($reason);
        }
        if ($reason = $holdrulecalc->on_shelf_holds_forbidden) {
            $self->unavailable($reason);
        }
    }

    return $self;
}

=head3 common_item_checks

Common checks for both OPAC and intranet.

=cut

sub common_item_checks {
    my ($self, $params) = @_;
    my $reason;

    my $item = $self->item;
    my $patron = $self->patron;
    my $itemcalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Item->new($item);

    $self->unavailable($reason) if $reason = $itemcalc->damaged;
    $self->unavailable($reason) if $reason = $itemcalc->lost;
    $self->unavailable($reason) if $reason = $itemcalc->restricted;
    $self->unavailable($reason) if $reason = $itemcalc->withdrawn;
    if ($reason = $itemcalc->notforloan) {
        unless ($reason->status < 0) {
            $self->unavailable($reason);
        } else {
            $self->note($reason);
        }
    }

    $self->unavailable($reason) if $reason = $itemcalc->from_another_library;
    if ($self->to_branch && ($reason = $itemcalc->transfer_limit($self->to_branch))) {
        $self->unavailable($reason);
    }
    if ($self->patron) {
        $self->unavailable($reason) if $reason = $itemcalc->held_by_patron($patron, $params);
    }

    if ($self->{'query_pickup_locations'}) {
        die('Context cache not provided') unless defined $params->{context_cache};
        if ($reason = $itemcalc->pickup_locations($patron, $params->{context_cache})) {
            if (@{$reason->to_libraries} == 0) {
                if ($reason->filtered == Mojo::JSON->true) {
                    $self->unavailable(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::NoPickUpLocations->new());
                } else {
                    $self->unavailable(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::CannotBeTransferred->new(
                        from_library => $item->holdingbranch
                    ));
                }
            }

            $self->note($reason);
        }
    }

    return $self;
}

=head3 common_library_item_rule_checks

Common checks for both OPAC and intranet.

=cut

sub common_library_item_rule_checks {
    my ($self) = @_;
    my $reason;

    my $item = $self->item;
    my $patron = $self->patron;
    my $libitemrule = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::LibraryItemRule->new({
        item => $item,
        patron => $patron,
    });

    if ($reason = $libitemrule->hold_not_allowed_by_library) {
        $self->unavailable($reason);
    } elsif ($reason = $libitemrule->hold_not_allowed_by_other_library) {
        $self->unavailable($reason);
    }

    return $self;
}

=head3 common_patron_checks

Common checks for both OPAC and intranet.

=cut

sub common_patron_checks {
    my ($self) = @_;
    my $reason;

    return $self unless $self->patron;

    my $patron = $self->patron;
    my $patroncalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Patron->new($patron);

    $self->unavailable($reason) if $reason = $patroncalc->debt_hold;
    $self->unavailable($reason) if $reason = $patroncalc->debarred;
    $self->unavailable($reason) if $reason = $patroncalc->exceeded_maxreserves;
    $self->unavailable($reason) if $reason = $patroncalc->gonenoaddress;
    $self->unavailable($reason) if $reason = $patroncalc->lost;
    if (($reason = $patroncalc->expired)
        && C4::Context->preference('BlockExpiredPatronOpacActions')) {
        $self->unavailable($reason);
    }

    return $self;
}

=head3 opac_specific_checks

OPAC-specific holdability checks.

=cut

sub opac_specific_issuing_rule_checks {
    my ($self, $branchcode) = @_;
    my $reason;

    my $item = $self->item;
    my $patron = $self->patron;
    $branchcode ||= $self->_get_reservescontrol_branchcode($item, $patron);
    my $args = {
        item => $item,
        branchcode => $branchcode,
    };
    $args->{patron} = $patron if $patron;
    my $holdrulecalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::CirculationRule->new($args);
    if ($reason = $holdrulecalc->opac_item_level_hold_forbidden) {
        $self->unavailable($reason);
    }

    return $self;
}


sub _get_reservescontrol_branchcode {
    my ($self, $item, $patron) = @_;

    my $branchcode;
    my $controlbranch = C4::Context->preference('ReservesControlBranch');
    if ($patron && $controlbranch eq 'PatronLibrary') {
        $branchcode = $patron->branchcode;
    } elsif ($item && $controlbranch eq 'ItemHomeLibrary') {
        $branchcode = $item->homebranch;
    } elsif ($controlbranch eq 'PickupLibrary' && C4::Context->userenv
             && C4::Context->userenv->{'branch'}) {
        $branchcode = C4::Context->userenv->{'branch'}
    }
    return $branchcode;
}

1;
