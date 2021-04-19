package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::LibraryItemRule;

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

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold;

=head3 new

With given parameters item (Koha::Item) and patron (Koha::Patron), selects the
effective library item rule and stores it into this object. Further calls to
methods of this object will use this library item rule.

PARAMETERS:
item    # Koha::Item object
patron  # Koha::Patron object

=cut

sub new {
    my $class = shift;
    my ($params) = @_;

    my $self = $class->SUPER::new(@_);

    my $independentBranch = C4::Context->preference('IndependentBranches');
    my $circcontrol       = C4::Context->preference('CircControl');
    my $patron = $self->{'patron'} = $params->{'patron'} ?
        $self->_validate_parameter($params, 'patron', 'Koha::Patron') : undef;
    my $item   = $self->{'item'} = $self->_validate_parameter($params,
                                            'item',   'Koha::Item');

    my $circ_control_branch;
    my $branchitemrule;
    if ($circcontrol eq 'ItemHomeLibrary' && $item) {
        $circ_control_branch = C4::Circulation::_GetCircControlBranch(
                                $item->unblessed, undef);
    } elsif ($circcontrol eq 'PatronLibrary' && $patron) {
        $circ_control_branch = C4::Circulation::_GetCircControlBranch(
                                undef, $patron->unblessed);
    } elsif ($circcontrol eq 'PickupLibrary') {
        $circ_control_branch = C4::Circulation::_GetCircControlBranch(
                                undef, undef);
    } else {
        bless $self, $class;
        $self->{'branchitemrule'} = undef;
        return $self;
    }

    $self->{'branchitemrule'} = C4::Circulation::GetBranchItemRule(
                        $circ_control_branch, $item->effective_itemtype);

    bless $self, $class;
}

=head3 hold_not_allowed_by_library

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedByLibrary if library item rules does
not allow holds.

=cut

sub hold_not_allowed_by_library {
    my ($self) = @_;

    return unless my $rule = $self->branchitemrule;

    if ($rule->{holdallowed} =~ m/^(0|not_allowed)$/) { # 0 means not_allowed in older Koha versions
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedByLibrary->new
    }
    return;
}

=head3 hold_not_allowed_by_library

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedFromOtherLibraries if library item rules
define restrictions for holds on items that are from another library than patron.

=cut

sub hold_not_allowed_by_other_library {
    my ($self) = @_;

    return unless my $rule = $self->branchitemrule;
    return unless my $item = $self->item;

    my $fromotherbranches = C4::Context->preference('canreservefromotherbranches');
    my $independentBranch = C4::Context->preference('IndependentBranches');

    my $patron = $self->patron;
    if ($rule->{holdallowed} =~ m/^(1|from_home_library)$/) { # 1 means from_home_library in older Koha versions
        if (!$patron) {
            # Since we don't know who is asking for item and from which
            # library, return NotAllowedFromOtherLibraries, but it should
            # be set only as an additional availability note
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedFromOtherLibraries->new;
        } elsif ($patron && $patron->branchcode ne $item->homebranch) {
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedFromOtherLibraries->new;
        }
    } elsif ($independentBranch && !$fromotherbranches) {
        if (!$patron) {
            # This should be stored as an additional note
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedFromOtherLibraries->new
        } elsif ($patron && $item->homebranch ne $patron->branchcode) {
            return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedFromOtherLibraries->new
        }
    }
    return;
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

1;
