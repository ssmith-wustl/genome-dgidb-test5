#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Genome::Model::Report::RefSeqMaq;

my ($id, $name) = (2733662090,'RefSeqMaq');#(2733662090,'RefSeqMaq');
my $report = Genome::Model::Report::RefSeqMaq->create(model_id =>$id, name=>$name);
#$report->resolve_reports_directory;
$report->generate_report_detail();
#$report->generate_report_brief();

__END__
# TODO: Fix this some how... we should create a model here rather than getting one
#    my @maq_content = $report->get_maq_content;
#    print (join("\n", @maq_content));

print ("dir:  " . $report->resolve_reports_directory . "\n");
    my $maq_content = $report->get_maq_content;#generate_report_brief();
#    print "got content:\t" . $maq_content . "\n";



#        my $the_model_id = 2661729970;#2722293016;
#        my $ref_seq_maq = Genome::Model::Report::RefSeqMaq->create(model_id =>$the_model_id,
#                                                                name=>"RefSeqMaq");
    #,
     #                                                           ref_seq_name => 22);
#        print "this:  " . $ref_seq_maq . "\n";
#        print "my refseq:  " . $ref_seq_maq->ref_seq_name . "\n";
#        $ref_seq_maq->generate_maq_file;
#        print $ref_seq_maq->get_brief_output . "\n";
#        print "DONE\n";
