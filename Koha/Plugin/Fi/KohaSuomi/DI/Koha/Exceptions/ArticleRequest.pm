package Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest;

use Modern::Perl;

use Exception::Class (

    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest' => {
        description => 'Something went wrong!',
    },
    'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::NotAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest',
        description => "Article request is not allowed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::BibLevelRequestNotAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest',
        description => "Bib level article request is not allowed.",
    },
     'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest::ItemLevelRequestNotAllowed' => {
        isa =>  'Koha::Plugin::Fi::KohaSuomi::DI::Koha::Exceptions::ArticleRequest',
        description => "Item level article request is not allowed.",
    }
);

1;
