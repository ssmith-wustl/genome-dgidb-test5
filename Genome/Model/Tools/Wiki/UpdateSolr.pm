
package Genome::Model::Tools::Wiki::UpdateSolr;

use Genome;

use LWP::Simple;
use XML::Simple;


class Genome::Model::Tools::Wiki::UpdateSolr {
    is => ['UR::Namespace::Command::RunsOnModulesInTree', 'Genome::Model::Tools::Wiki'],
    has => {
        days_ago => { 
            is => 'Text', 
            doc => 'How many days worth of wiki updates to send to solr', 
            default => '1',
            is_optional => 1 },
    },
    doc => 'Gets DAYS_AGO days worth of changes from wiki, submits to solr search engine for indexing',
};


sub help_synopsis {

    return "gmt wiki update-solr [ --days-ago N ]\n";
}


sub execute {

    my ($self) = @_;

    my $cache = Genome::Memcache->server();
    my $now = UR::Time->now();
    my $timeout = 60 * 60 * 24; # this is just storing which changes we've notified solr about

    # get/parse recent changes from wiki rss feed
    my $url = $self->url();
    my $raw_xml = LWP::Simple::get($url) || die "failed to get url: $url\n$!";
    my $parsed_xml = XML::Simple::XMLin($raw_xml);

    # title, link, description, pubDate, comments, dc:creator
    for my $item (@{ $parsed_xml->{'channel'}->{'item'} }) {

        # key is title and date of change
        my $key = cache_key($item);

        if ( ! defined($cache->get($key)) ) {

            my $doc = Genome::Wiki::Document->get( title => $item->{'title'} )
                || die 'cant get doc for title: ' . $item->{'title'};

            # NOTE: if this is slow we could Genome::Search->add(@all_docs)
            # but for now adding one, setting cache, adding another, setting cache...
            
            # post item to solr
            Genome::Search->add($doc) || die 'Error: failed to add doc with title ' . $doc->title();

            # mark as done
            $cache->set($key, $now, $timeout );     

            print "just added: " . $doc->title();
        }
    last;
    }
}



sub cache_key {

    my ($item) = @_;

    my $title = $item->{'title'} || die 'couldnt make key- no title';
    my $date = $item->{'pubDate'} || die "couldnt make key- no pubDate for item $title";

    my $key = join('---', 'wiki', $date, $title);
    return $key;
}



sub url {

    my ($self) = @_;

    my $url = join( '',
        'https://gscweb.gsc.wustl.edu/mediawiki/index.php?title=Special:RecentChanges&feed=rss&days=',
        $self->days_ago() );

    return $url;
}


1;


