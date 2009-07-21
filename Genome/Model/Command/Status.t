#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use Test::More tests => 3;
use XML::LibXML;

use above 'Genome';

my $model_id = '2771359026';

my $model_status = Genome::Model::Command::Status->create(genome_model_id=>$model_id, display_output=>0);

ok($model_status);

my $rv = $model_status->execute;

is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $parse_xml_test = 0;

my $model_id_test = 0;

my $xml = $model_status->xml();
my $parser = XML::LibXML->new();
my $doc = $parser->parse_string($xml);

ok($doc);

my $root = $doc->getDocumentElement();
my $query = '//model/@model-id';
my $model_id_xml = $root->findvalue($query);

if ($model_id eq $model_id_xml) {
    $model_id_test = 1;
}

is($model_id_test,1,"Testing success: Expected to retrieve model-id $model_id from parsed XML, retrieved model-id $model_id_xml.");

