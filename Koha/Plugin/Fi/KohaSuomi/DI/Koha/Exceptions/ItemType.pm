package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ItemType;

use Modern::Perl;

use Exception::Class (

     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ItemType' => {
        description => 'Something went wrong!',
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ItemType::NotForLoan' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ItemType',
        description => "This type of items are not for loan.",
        fields => ["itemtype", "status", "code"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ItemType::NotFound' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ItemType',
        description => "Item type not found",
        fields => ['itemtype'],
    },

);

1;
