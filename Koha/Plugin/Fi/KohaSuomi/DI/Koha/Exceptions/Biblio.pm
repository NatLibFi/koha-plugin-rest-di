package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio;

use Modern::Perl;

use Exception::Class (

    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio' => {
        description => 'Something went wrong!',
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::AnotherItemCheckedOut' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio',
        description => "Another item from same biblio already checked out.",
        fields => ["itemnumbers"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::CheckedOut' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio',
        description => "Biblio is already checked out for patron.",
        fields => ['biblionumber'],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::NoAvailableItems' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio',
        description => "Biblio does not have any available items.",
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::NotFound' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio',
        description => "Biblio not found.",
        fields => ['biblionumber'],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio::PickupLocations' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Biblio',
        description => "Items in this biblio can only be transferred to following libraries",
        fields => ["to_libraries"],
    },

);

1;
