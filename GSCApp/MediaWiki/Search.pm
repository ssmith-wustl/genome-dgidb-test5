package GSCApp::MediaWiki::Search;

use strict;
use warnings;

use LWP::Simple;
use XML::XPath;
use XML::XPath::Parser;

use Data::Dumper;


my $WIKI_URL = 'https://gscweb.gsc.wustl.edu/wiki/';
my $SOLR_SERVER = 'http://linuscs24:8983';

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub query {

    my ($self, %params) = @_;

    $self->{'q'}    = $params{'q'}     || return;
    $self->{'start'} = $params{'start'} || 0;
    $self->{'rows'}  = $params{'rows'}  || 100;
 
    return $self->get_parsed_docs();
}

sub send_query {

    my ($self) = @_;

    my $get_path =
          $SOLR_SERVER
        . '/solr/select/?q='
        . $self->{'q'}
        . '&version=2.2&start='
        . $self->{'start'}
        . '&rows='
        . $self->{'rows'}
        . '&indent=on';

    my $c = get($get_path);
    return $c;
}

sub get_docs {

    my ($xml) = @_;

    my $xp = XML::XPath->new( 'xml' => $xml );
    my $ns = $xp->find('/response/result/doc');

    return $ns->get_nodelist();
}


sub get_parsed_docs {

    my ($self) = @_;

    my $xml = $self->send_query();

    my @pdocs; # parsed docs
    my @docs = get_docs($xml);

    DOC:
    for my $doc (@docs) {

        my $pdoc = {};

        CHILD:
        for my $child ($doc->getChildNodes()) {

            my $key = $child->getAttribute('name');
            next if !$key;

            $pdoc->{$key} = $child->string_value();
            if ($key eq 'title') {
                $pdoc->{'link'} = $WIKI_URL . $child->string_value();
            }
        }

        push @pdocs, $pdoc;
    }

    return \@pdocs;
}


1;



