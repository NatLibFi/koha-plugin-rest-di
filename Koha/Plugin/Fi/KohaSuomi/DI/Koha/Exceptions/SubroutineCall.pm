package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exception::SubroutineCall;

# Copyright 2016 Koha-Suomi Oy
# Copyright 2020 University of Helsinki (The National Library Of Finland)
#
# This file is part of Koha.
#

use Modern::Perl;

use Exception::Class (
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exception::SubroutineCall' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions',
        description => 'Subroutine is called wrongly',
    },
);

return 1;
