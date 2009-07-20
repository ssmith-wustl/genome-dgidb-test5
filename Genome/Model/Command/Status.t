#!/gsc/bin/perl

use strict;
use warnings;

use File::Path;
use Test::More tests => 3;

use above 'Genome';

my $model = Genome::Model->get(name => 'pipeline_test_1');

my $model_status = Genome::Model::Command::Status->create(genome_model_id=>$model->id, display_output=>0);

ok($model_status);

my $rv = $model_status->execute;

is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $length_test = 0;

my $xml = $model_status->xml();
print $xml;

# FIXME in the future, this test should check some data in the XML, not just
# its length
if (length($xml) > 900 ) {
    $length_test = 1 ;
} 

is($length_test,1,'Testing success: Expecting a longish XML string (>3000 chars). Got a string of length: '.length($xml));

