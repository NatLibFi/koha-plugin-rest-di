package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold;

use Modern::Perl;

use Exception::Class (

     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold' => {
        description => 'Something went wrong!',
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ItemLevelHoldNotAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Item level hold is not allowed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::OnlyItemLevelHoldAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Patron has existing item level hold(s). Biblio level hold not allowed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::MaximumHoldsReached' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Maximum number of holds have been reached.",
        fields => ["max_holds_allowed", "current_hold_count"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::MaximumHoldsForRecordReached' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Maximum number of holds for a record have been reached.",
        fields => ["max_holds_allowed", "current_hold_count"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedByLibrary' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "This library does not allow holds.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedFromOtherLibraries' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Cannot hold from other libraries.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::NotAllowedInOPAC' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Holds are disabled in OPAC.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::OnShelfNotAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "On-shelf holds are not allowed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold::ZeroHoldsAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Hold',
        description => "Matching hold rule that does not allow any holds.",
    },

);

1;
