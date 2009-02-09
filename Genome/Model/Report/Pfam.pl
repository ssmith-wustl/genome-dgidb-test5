#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Report::Pfam;

my $model_id = 2733662090; #2661729970;
my $name = 'Pfam';
my $report = Genome::Model::Report::Pfam->create(model_id =>$model_id, name=>$name);
$report->_process_coding_transcript_file('Pfam.t.dat');

__END__
my $model = Genome::Model->get($model_id);
my ($id, $name) = ($model_id,'Pfam');

my $report = Genome::Model::Report::Pfam->create(model_id =>$id, name=>$name);
#   $report->generate_report_brief; 
$report->generate_report_detail;

