package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Availability::Checks::Checkout;

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

use Koha::DateUtils;
use Koha::Items;

use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio;
use Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout;

sub new {
    my ($class) = @_;

    my $self = {};

    bless $self, $class;
}

=head3 no_more_renewals

Returns Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::NoMoreRenewals if no more renewals are
allowed for given checkout.

=cut

sub no_more_renewals {
    my ($self, $issue) = @_;

    return unless $issue;
    my ($status) = C4::Circulation::CanBookBeRenewed($issue->borrowernumber,
             $issue->itemnumber);
    if ($status == 0) {
        return Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::NoMoreRenewals->new;
    }
    return;
}

1;
