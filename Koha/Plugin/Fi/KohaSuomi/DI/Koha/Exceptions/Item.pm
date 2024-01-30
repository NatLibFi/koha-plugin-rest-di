package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item;

use Modern::Perl;

use Exception::Class (

    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item' => {
        description => 'Something went wrong!',
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::AlreadyHeldForThisPatron' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item already held for this patron.",
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::CannotBeTransferred' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item cannot be transferred from holding library to given library.",
        fields => ["from_library", "to_library"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::CheckedOut' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item has already been checked out.",
        fields => ["borrowernumber", "due_date"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Damaged' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is marked as damaged.",
        fields => ["code", "status"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::FromAnotherLibrary' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Libraries are independent and item is not from this library.",
        fields => ["current_library", "from_library"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Held' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item held.",
        fields => ["borrowernumber", "status"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::HighHolds' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "High demand item. Loan period shortened.",
        fields => ["num_holds", "duration", "returndate"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Lost' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is marked as lost.",
        fields => ["code", "status"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::NotForLoan' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is marked as not for loan.",
        fields => ["code", "status"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::NotFound' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item not found.",
        fields => ['itemnumber'],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::NotForLoanForcing' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is marked as not for loan, but it is possible to override.",
        fields => ["notforloan"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Restricted' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is marked as restricted.",
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Transfer' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is being transferred.",
        fields => ["datesent", "from_library", "to_library"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::PickupLocations' => {
        isa => 'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item can only be transferred to following libraries",
        fields => ["from_library", "to_libraries", "filtered"],
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::NoPickUpLocations' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item does not have valid pick up locations."
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::UnknownBarcode' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item has unknown barcode, or no barcode at all.",
        fields => ["barcode"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Withdrawn' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item is marked as withdrawn.",
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item::Recalled' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Item',
        description => "Item has been recalled.",
    }

);

1;
