package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout;

use Modern::Perl;

use Exception::Class (

     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout' => {
        description => 'Something went wrong!',
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::DueDateBeforeNow' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => 'Given due date is already in the past.',
        fields => ["duedate", "now"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::Fee' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "There are checkout fees.",
        fields => ["amount"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::InvalidDueDate' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => 'Given due date is invalid.',
        fields => ["duedate"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::MaximumCheckoutsReached' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "Maximum number of checkouts have been reached, or none allowed.",
        fields => ["max_checkouts_allowed", "current_checkout_count"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::MaximumOnsiteCheckoutsReached' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "Maximum number of on-site checkouts have been reached.",
        fields => ["max_onsite_checkouts", "current_onsite_checkouts"],
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::NoMoreRenewals' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "No more renewals are allowed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::NoRenewalForOnsiteCheckouts' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "On-site checkouts cannot be renewed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::OnsiteCheckoutsDisabled' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "On-site checkouts are disabled.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::OnsiteCheckoutWillBeSwitched' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "On-site checkout will be switched to normal checkout.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::PreviouslyCheckedOut' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "This biblio has been previously checked out by this patron.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::Renew' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "Checkout will be renewed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout::ZeroCheckoutsAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::Checkout',
        description => "Matching issuing rule that does not allow any checkouts.",
    },

);

1;
