package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::CirculationRule;

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

use base qw(Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks);

use C4::Circulation;
use C4::Context;
use C4::Reserves;

use Koha::CirculationRules;
use Koha::Items;
use Koha::Logger;

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold;

=head3 new

OPTIONAL PARAMETERS:

* categorycode      Attempts to match issuing rule with given categorycode
* itemtype          Attempts to match issuing rule with given itemtype
* branchcode        Attempts to match issuing rule with given branchcode

* item              Stores item into the object for reusability. Also
                    attempts to match issuing rule with item's itemtype
                    unless specified with "itemtype" parameter.
* patron            Stores patron into the object for reusability. Also
                    Attempts to match issuing rule with patron's categorycode
                    unless specified with "categorycode" parameter.
* biblioitem        Attempts to match issuing rule with itemtype from given
                    biblioitem as a fallback

Caches circultion rules momentarily to help performance in biblio availability
calculation. This is helpful because a biblio may have multiple items matching
the same circulation rule and this lets us avoid multiple, unneccessary queries into
the database.

=cut

sub new {
    my $class = shift;
    my ($params) = @_;

    my $self = $class->SUPER::new(@_);

    my $patron     = $self->_validate_parameter($params, 'patron', 'Koha::Patron');
    my $item       = $self->_validate_parameter($params, 'item', 'Koha::Item');
    my $biblioitem = $self->_validate_parameter($params, 'biblioitem', 'Koha::Biblioitem');

    unless ($params->{'itemtype'}) {
        $params->{'itemtype'} = $item
            ? $item->effective_itemtype
            : $biblioitem
              ? $biblioitem->itemtype
              : undef;
    }
    unless ($params->{'categorycode'}) {
        $params->{'categorycode'} = $patron ? $patron->categorycode : undef;
    }
    unless ($params->{'ccode'}) {
        $params->{'ccode'} = $item ? $item->ccode : undef;
    }
    unless ($params->{'permanent_location'}) {
        $params->{'permanent_location'} = $item ? $item->permanent_location : undef;
    }

    $self->{'use_cache'} = $params->{'use_cache'} // 1;

    delete($params->{'patron'});
    delete($params->{'item'});
    delete($params->{'biblioitem'});
    delete($params->{'use_cache'});

    $self->{'patron'} = $patron;
    $self->{'item'} = $item;
    $self->{'rule_params'} = $params;

    bless $self, $class;
}

=head3 maximum_checkouts_reached

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::MaximumCheckoutsReached if maximum number
of checkouts have been reached by patron.

=cut

sub maximum_checkouts_reached {
    my ($self, $item, $patron) = @_;

    return unless $patron ||= $self->patron;
    return unless $item ||= $self->item;

    my $toomany = C4::Circulation::TooMany(
            $patron->unblessed,
            $item,
    );

    if ($toomany) {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::MaximumCheckoutsReached->new(
            error => $toomany->{reason},
            max_checkouts_allowed => 0+$toomany->{max_allowed},
            current_checkout_count => 0+$toomany->{count},
        );
    }
    return;
}

=head3 maximum_holds_for_record_reached

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::MaximumHoldsForRecordReached if maximum number
of holds on biblio have been reached by patron.

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ZeroHoldsAllowed if no holds are allowed at all.

OPTIONAL PARAMETERS:
nonfound_holds      Allows you to pass Koha::Holds object to improve performance
                    by avoiding another query to reserves table.
                    (Found holds don't count against a patron's holds limit)
biblionumber        Allows you to specify biblionumber; if not given, item's
                    biblionumber will be used (recommended; but requires you to
                    provide item while instantiating this class).

=cut

sub maximum_holds_for_record_reached {
    my ($self, $params) = @_;

    return unless my $per_record_rule = $self->_get_rule('holds_per_record');
    return unless my $item = $self->item;

    my $biblionumber = $params->{'biblionumber'} ? $params->{'biblionumber'}
                : $item->biblionumber;
    if ($per_record_rule->rule_value ne '' && $per_record_rule->rule_value > 0) {
        my $holds_on_this_record;
        unless (exists $params->{'nonfound_holds'}) {
            $holds_on_this_record = Koha::Holds->search({
                borrowernumber => 0+$self->patron->borrowernumber,
                biblionumber   => 0+$biblionumber,
                found          => undef,
            })->count;
        } else {
            $holds_on_this_record = @{$params->{'nonfound_holds'}};
        }
        if ($holds_on_this_record >= $per_record_rule->rule_value) {
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::MaximumHoldsForRecordReached->new(
                max_holds_allowed => 0+$per_record_rule->rule_value,
                current_hold_count => 0+$holds_on_this_record,
            );
        }
    } else {
        return $self->zero_holds_allowed;
    }
    return;
}

=head3 maximum_holds_reached

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::MaximumHoldsReached if maximum number
of holds have been reached by patron.

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ZeroHoldsAllowed if no holds are allowed at all.

=cut

sub maximum_holds_reached {
    my ($self) = @_;

    return unless my $reserves_rule = $self->_get_rule('reservesallowed');
    my $itemtype = $self->{'rule_params'}->{'itemtype'};
    my $controlbranch = C4::Context->preference('ReservesControlBranch');

    if ($reserves_rule->rule_value ne '' && $reserves_rule->rule_value > 0) {
        # Get patron's hold count for holds that match the found issuing rule
        my $hold_count = $self->_patron_hold_count($itemtype, $controlbranch);
        if ($hold_count >= $reserves_rule->rule_value) {
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::MaximumHoldsReached->new(
                max_holds_allowed => 0+$reserves_rule->rule_value,
                current_hold_count => 0+$hold_count,
            );
        }
    } else {
        return $self->zero_holds_allowed;
    }
    return;
}

=head3 on_shelf_holds_forbidden

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::OnShelfNotAllowed if effective issuing rule
restricts on-shelf holds.

=cut

sub on_shelf_holds_forbidden {
    my ($self) = @_;

    return unless my $rule = $self->_get_rule('onshelfholds');
    return unless my $item = $self->item;
    my $on_shelf_holds = $rule->rule_value;

    if ($on_shelf_holds == 0) {
        my $hold_waiting = Koha::Holds->search({
            found => 'W',
            itemnumber => 0+$item->itemnumber,
            priority => 0
        })->count;
        if (!$item->onloan && !$hold_waiting) {
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::OnShelfNotAllowed->new;
        }
        return;
    } elsif ($on_shelf_holds == 1) {
        return;
    } elsif ($on_shelf_holds == 2) {
        my $items = Koha::Items->search({ biblionumber => $item->biblionumber });

        my $any_available = 0;

        while ( my $i = $items->next ) {
            unless ($i->itemlost
              || $i->notforloan > 0
              || $i->withdrawn
              || $i->onloan
              || C4::Reserves::IsItemOnHoldAndFound( $i->id )
              || ( $i->damaged
                && !C4::Context->preference('AllowHoldsOnDamagedItems') )
              || Koha::ItemTypes->find( $i->effective_itemtype() )->notforloan) {
                if ($self->_holds_allowed($i) ) {
                    $any_available = 1;
                    last;
                }
            }
        }
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::OnShelfNotAllowed->new if $any_available;
    }
    return;
}

=head3 opac_item_level_hold_forbidden

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ItemLevelHoldNotAllowed if item-level holds are
forbidden in OPAC.

=cut

sub opac_item_level_hold_forbidden {
    my ($self) = @_;

    return unless my $rule = $self->_get_rule('opacitemholds');

    if ($rule->rule_value ne '' && $rule->rule_value eq 'N') {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ItemLevelHoldNotAllowed->new;
    }
    return;
}

=head3 zero_checkouts_allowed

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::ZeroCheckoutsAllowed if checkouts are not
allowed at all.

=cut

sub zero_checkouts_allowed {
    my ($self) = @_;

    return unless my $rule = $self->_get_rule('maxissueqty');

    if ($rule->rule_value ne '' && $rule->rule_value == 0) {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::ZeroCheckoutsAllowed->new;
    }
    return;
}

=head3 zero_holds_allowed

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ZeroHoldsAllowed if holds are not
allowed at all.

This will inspect both "reservesallowed" and "holds_per_record" value in effective
issuing rule.

=cut

sub zero_holds_allowed {
    my ($self) = @_;

    return unless my $reserves_rule = $self->_get_rule('reservesallowed');
    return unless my $per_record_rule = $self->_get_rule('holds_per_record');

    if (($reserves_rule->rule_value ne '' && $reserves_rule->rule_value == 0)
        || ($per_record_rule->rule_value ne '' && $per_record_rule->rule_value == 0)
    ) {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ZeroHoldsAllowed->new;
    }
    return;
}

=head3 no_article_requests_allowed

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::NotAllowed if article requests are not
allowed at all.

=cut

sub no_article_requests_allowed {
    my ($self) = @_;

    return unless my $rule = $self->_get_rule('article_requests');

    if ($rule->rule_value eq 'no') {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::NotAllowed->new;
    }

    return;
}

=head3 opac_bib_level_article_request_forbidden

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::BibLevelRequestNotAllowed if biblio-level article requests are
forbidden in OPAC.

=cut

sub opac_bib_level_article_request_forbidden {
    my ($self) = @_;

    return unless my $rule = $self->_get_rule('article_requests');

    if ($rule->rule_value ne 'yes' && $rule->rule_value ne 'bib_only') {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::BibLevelRequestNotAllowed->new;
    }
    return;
}


=head3 opac_item_level_article_request_forbidden

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::ItemLevelRequestNotAllowed if item-level article requests are
forbidden in OPAC.

=cut

sub opac_item_level_article_request_forbidden {
    my ($self) = @_;

    return unless my $rule = $self->_get_rule('article_requests');

    if ($rule->rule_value ne 'yes' && $rule->rule_value ne 'item_only') {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::ItemLevelRequestNotAllowed->new;
    }

    return;
}

sub _patron_hold_count {
    my ($self, $itemtype, $controlbranch) = @_;

    $itemtype ||= '*';
    my $branchcode;
    my $branchfield = 'me.branchcode';
    $controlbranch ||= C4::Context->preference('ReservesControlBranch');

    # Note: Reserve schema has confusing names for relationships (borrowernumber, biblionumber, itemnumber), 
    # so try to play along.
    my $patron = $self->patron;
    if ($self->patron && $controlbranch eq 'PatronLibrary') {
        $branchfield = 'borrowernumber.branchcode';
        $branchcode = $patron->branchcode;
    } elsif ($self->item && $controlbranch eq 'ItemHomeLibrary') {
        $branchfield = 'itemnumber.homebranch';
        $branchcode = $self->item->homebranch;
    }

    my $cache;
    my $cache_key = 'holds_of_'.$patron->borrowernumber.'-'.$itemtype.'-'.$branchcode;
    if ($self->use_cache) {
        $cache = Koha::Caches->get_instance('availability');
        my $cached = $cache->get_from_cache($cache_key);
        if (defined $cached) {
            return $cached;
        }
    }

    my $holds = Koha::Holds->search({
        'me.borrowernumber' => $patron->borrowernumber,
        $branchfield => $branchcode,
        '-and' => [
            '-or' => [
                $itemtype ne '*' && C4::Context->preference('item-level_itypes') == 1 ? [
                    { 'itype' => $itemtype },
                    { 'biblioitems.itemtype' => $itemtype }
                ] : [ { 'biblioitems.itemtype' => $itemtype } ]
            ]
        ]}, {
        join => ['borrowernumber', 'biblionumber', 'itemnumber', {'biblionumber' => 'biblioitems'}],
        '+select' => [ 'borrowernumber.branchcode', 'itemnumber.homebranch' ],
        '+as' => ['borrowernumber.branchcode', 'itemnumber.homebranch' ]
    })->count;

    if ($self->use_cache) {
        $cache->set_in_cache($cache_key, $holds, { expiry => 10 });
    }

    return $holds;
}

sub _validate_parameter {
    my ($self, $params, $key, $ref) = @_;

    if (exists $params->{$key}) {
        if (ref($params->{$key}) eq $ref) {
            return $params->{$key};
        } else {
            Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::BadParameter->throw(
                "Parameter $key must be a $ref object."
            );
        }
    }
}

sub _holds_allowed {
    my ($self, $item) = @_;

    my $args = {
        item => $item,
        branchcode => $self->{'rule_params'}->{'branchcode'} // undef,
        use_cache => $self->{'use_cache'},
    };
    $args->{patron} = $self->patron if $self->patron;

    my $holdrulecalc = Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::CirculationRule->new($args);

    return !$holdrulecalc->zero_holds_allowed;
}

sub _get_rule {
    my ($self, $rule_name) = @_;

    # Get a matching circulation rule
    my $rule_params = $self->{'rule_params'};
    $rule_params->{'rule_name'} = $rule_name;
    my $rule;
    my $cache;
    my $cache_key = 'circ_rule';
    for my $key (keys %$rule_params) {
        $cache_key .= '-' . ($rule_params->{$key} ? $rule_params->{$key} : '*');
    }
    if ($self->{'use_cache'}) {
        $cache = Koha::Caches->get_instance('availability');
        my $cached = $cache->get_from_cache($cache_key);
        if ($cached) {
            $rule = Koha::CirculationRule->new->set($cached);
        }
    }

    unless ($rule) {
        $rule = Koha::CirculationRules->get_effective_rule($rule_params);
        if ($rule && $self->{'use_cache'}) {
            $cache->set_in_cache($cache_key, $rule->unblessed, { expiry => 10 });
        }
    }

    return $rule;
}

1;
