package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron;

use Modern::Perl;

use Exception::Class (

     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron' => {
        description => 'Something went wrong!',
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::AgeRestricted' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Age restriction applies for patron.",
        fields => ["age_restriction"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::CardExpired' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron's card has expired.",
        fields => ["expiration_date"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::CardLost' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron's card has been marked as lost.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::Debarred' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron is debarred.",
        fields => ["expiration", "comment"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::DebarredOverdue' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron is debarred because of overdue checkouts.",
        fields => ["number_of_overdues"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::Debt' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron has debts.",
        fields => ["max_outstanding", "current_outstanding"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::DebtGuarantees' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron's guarantees have debts.",
        fields => ["max_outstanding", "current_outstanding", "guarantees"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::DuplicateObject' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron cardnumber and userid must be unique",
        fields => ["conflict"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::FromAnotherLibrary' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Libraries are independent and this patron is from another library than we are now logged in.",
        fields => ["patron_branch", "current_branch"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::GoneNoAddress' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron gone no address.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::NotFound' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron not found.",
        fields => ['borrowernumber'],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron::OtherCharges' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Patron',
        description => "Patron has other outstanding charges.",
        fields => ["balance", "other_charges"],
    },

);

1;
