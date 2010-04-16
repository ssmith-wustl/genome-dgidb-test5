package Genome::Search::Email::Simple;

use strict;
use warnings;

use Genome;

use constant MONTHS => {
    Jan => '01',
    Feb => '02',
    Mar => '03',
    Apr => '04',
    May => '05',
    Jun => '06',
    Jul => '07',
    Aug => '08',
    Sep => '09',
    Oct => '10',
    Nov => '11',
    Dec => '12',
};

class Genome::Search::Email::Simple { 
    is => 'Genome::Search',
    has => [
        type => {
            is => 'Text',
            default_value => 'mail'
        }
    ]
};

sub _add_details_result_xml {
    my $class = shift;
    my $doc = shift;
    my $result_node = shift;
    
    my $xml_doc = $result_node->ownerDocument;
    
    my $content = $doc->value_for('content');
    my $id = $doc->value_for('id');

    my ($list_name, $year_month, $message_id) = split(/\//,$id);

    my $mail_url = "http://gscsmtp/pipermail/$id.html";
    my $url_node = $result_node->addChild( $xml_doc->createElement("url") );
    $url_node->addChild( $xml_doc->createTextNode($mail_url) );

    my $list_url = 'http://gscsmtp.wustl.edu/cgi-bin/mailman/listinfo/' . $list_name;
    my $list_url_node = $result_node->addChild( $xml_doc->createElement("list-url") );
    $list_url_node->addChild( $xml_doc->createTextNode($list_url) );

    my $year_month_url = join('', 'http://gscsmtp.wustl.edu/pipermail/',$list_name,'/',$year_month,'/date.html');
    my $year_month_url_node = $result_node->addChild( $xml_doc->createElement("year-month-url") );
    $year_month_url_node->addChild( $xml_doc->createTextNode($year_month_url) );

    my $list_name_node = $result_node->addChild( $xml_doc->createElement('list-name') );
    $list_name_node->addChild( $xml_doc->createTextNode($list_name) );
    my $year_month_node = $result_node->addChild( $xml_doc->createElement('year-month') );
    $year_month_node->addChild( $xml_doc->createTextNode($year_month) );
    my $message_id_node = $result_node->addChild( $xml_doc->createElement('message-id') );
    $message_id_node->addChild( $xml_doc->createTextNode($message_id) );

    my $blurb = $class->mail_blurb($content);
    my $blurb_node = $result_node->addChild( $xml_doc->createElement('blurb') );

#TODO Refactor to enable blurb based on query
#    if($query and $blurb =~ m/(.*?)($query)(.*)/i) {
#        $blurb_node->addChild( $xml_doc->createTextNode($1) );
#
#        my $query_highlight_node = $blurb_node->addChild( $xml_doc->createElement('span') );
#        $query_highlight_node->addChild( $xml_doc->createAttribute('class','highlight') );
#        $query_highlight_node->addChild( $xml_doc->createTextNode($2) );
#
#        $blurb_node->addChild( $xml_doc->createTextNode($3) );
#    } else {
        $blurb_node->addChild( $xml_doc->createTextNode($blurb) );
#    }
    
    return $result_node;
}

sub generate_document {
    my $class = shift();
    my $email = shift();
    
    my $date = $class->parse_date($email->header('Date')) || '1999-01-01T01:01:01Z';

    my @fields; 
    push @fields, WebService::Solr::Field->new( class     => 'Email::Simple' );
    push @fields, WebService::Solr::Field->new( title     => $email->header('Subject') );
    push @fields, WebService::Solr::Field->new( id        => $email->header('X-Genome-Search-ID') );
    push @fields, WebService::Solr::Field->new( object_id => $email->header('X-Genome-Search-ID') );
    push @fields, WebService::Solr::Field->new( timestamp => $date );
    push @fields, WebService::Solr::Field->new( content   => $email->body() );
    push @fields, WebService::Solr::Field->new( type      => 'mail' );

    my $doc = WebService::Solr::Document->new(@fields);
    return $doc;
}

sub parse_date {
    my $class = shift;

    # Main cases:
    # Tue, 7 Apr 2009 11:54:07 -0500
    # Fri,  3 Apr 2009 15:44:31 -0600 (CST)
    #
    # another case:
    # 05 Aug 2009 12:22:00 -0700)

    my ($effed_date) = @_;

    my ($dow,$day,$month_abbrev,$year,$time)  = split(/\s+/,$effed_date);

    if ($day !~ /\d+/) {
        # handling: 05 Aug 2009 12:22:00 -0700)
        ($day,$month_abbrev,$year,$time) = split(/\s+/,$effed_date); 
    } 

    if ($day !~ /\d+/) {
        die "Error! Day should be numeric not '$day' (parsed from $effed_date)";
    }

    if ($year !~ /\d{4}/) {
        die "Error! Year looks funny: '$day' parsed from $effed_date";
    }

    my $month = $class->MONTHS->{$month_abbrev};
    $day = sprintf("%0.2d",$day);

    my $date = join( '-', ($year , $month, $day ) );
    $date .= 'T' . $time . 'Z';

    return $date;
}

sub mail_blurb {
    my $class = shift;
    my ($text, $query) = @_;

    $text =~ s/\s{2}/ /g;
    $text =~ s/-------- Original Message --------(.|\n)*//g;
    $text =~ s/\n/ /g;

    my $summarystart = 0;

    if($query) {
        #find summary region around query in result
        my $querypos = index($query, $text);

        if($querypos -75 > $summarystart) {
          $summarystart = $querypos - 75;
        }


    }

    my $summary = substr($text,$summarystart,150);

    if (length($text) > length($summary)) {
        $summary .= ' ...';
    }

    if ($summarystart > 0) {
        $summary = '... ' . $summary;
    }

    return $summary;
}

#OK!
1;
