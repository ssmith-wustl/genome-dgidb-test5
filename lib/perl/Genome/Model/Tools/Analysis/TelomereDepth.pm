#Telomere Depth
package Genome::Model::Tools::Analysis::TelomereDepth;

use strict;
use warnings;
use Genome::Model::Tools::Analysis;
use IO::File;
use List::Util qw(max);


class Genome::Model::Tools::Analysis::TelomereDepth {
  is => 'Command',
  has => [
    roi_file => { type => 'String', doc => "Regions of interest - BED file" },
    model_ids => { type => 'String', is_optional => 1, doc => "model ID" },
    model_group_id => { type => 'String', is_optional => 1, doc => "model group ID" },
    output_dir => { type => 'String', is_optional => 1, doc => "Output Directory" },
    sample_type => { type => 'String', is_optional => 1, doc => "Type of Sample" },
    simulate => { type => 'Boolean', is_optional => 1, default => 0, doc => "" },
  ],
  doc => "",
};

sub help_detail {
  return <<HELP;
Takes a list of ROIs and models, and finds normalized read depth of telomeres

HELP
}

sub _doc_authors {
  return "Charles Lu";
}

sub execute {
  # Grab the inputs into local variables
  my $self = shift;
  my $roi_file = $self->roi_file;
  my $model_ids = $self->model_ids;
  my $model_group_id = $self->model_group_id;
  my $simulate = $self->simulate;
  my $output_dir = $self->output_dir;
  my $sample_type = $self->sample_type;

  #process user-supplied models
  my @models=();
  if( $model_group_id ) {
      my $model_group = Genome::ModelGroup->get(id=>$model_group_id, -hints => ["models"]);
      @models = $model_group->models;
  }
  elsif( $model_ids ) {
      my @modelIDs = split( /,/, $model_ids );
      @models = map{ Genome::Model->get($_) } @modelIDs;
      #my $b = Genome::Model::Build->get($build_id);
  }

  my @ROIs = getROI($roi_file); 
  my $hap_coverage = get_hap_coverage();
  grab_read_depth(\@models, \@ROIs, $hap_coverage); 

  return 1;
}

sub grab_read_depth {

  my $models = shift;
  my $ROIs = shift;
  my $hap_coverage = shift;

  foreach my $model(@$models) {

  my $build = $model->last_succeeded_build;
  unless(defined $build) { #if can't find successful build, grab the 1st build ever made
      my @builds = $model->builds;
      #$build = $builds[0];
      $build = max(@builds); #alternatively grab the most recent build (assuming increasing build id's)
      if (!$build) { die "finding the max build did not work!\n"; }
  }
  my $ref_seq = $build->reference_sequence_build->name;
  if($ref_seq =~ /GRCh37/ && $ref_seq =~ /Telomere720/) { #deal with Nate's excessively long ref seq name
      my @temp = split(/\-Appended\-/,$ref_seq);
      $ref_seq = $temp[0];
  }

  my $sample = $model->subject->source_common_name;
  my $type = $build->subject->common_name;
  my $BAM_file = $build->whole_rmdup_bam_file;

  #grab haploid coverage
  my $coverage = $build->get_metric("haploid_coverage"); #won't work on failed builds
  #my $coverage = get_map_undup_readcount($build);
  #my $coverage = $hap_coverage->{"$sample($type)"};
  if(!$coverage) {
      print STDERR "Error: no hap coverage found for $sample\t$type\n";
      exit 2;
  }
  my $count;
  foreach my $roi(@$ROIs) {
      $count = `samtools view -F 0x404 $BAM_file $roi | grep -P '100M|99M|98M' | wc -l`;
      chomp($count);
            #normalize:
            my $count2 = $count/$coverage;
      print "$sample($type)\t$roi\t$ref_seq\t$count\t$count2\n";
  }

  my $x = 1;

    }
}


sub get_hap_coverage {

    my $samples = {
               'SJNBL001(normal)'=> '2876183632',
                     'SJNBL001(tumor)' => '2876193755',
               'SJNBL002(normal)'=> '2875121649',
                     'SJNBL002(tumor)' => '2875163634',
         'SJNBL037(normal)'=> '2876070927',
                     'SJNBL037(tumor)' => '2876071251',
         'SJNBL044(normal)'=> '2876070294',
                     'SJNBL044(tumor)' => '2876070368',
         'SJMB028(normal)' => '2875163578',
                     'SJMB028(tumor)'  => '2875103130',
    };

  my $data={};
      while(my($sample,$modelID) = each %$samples) {
    my $model = Genome::Model->get($modelID);
    my $build = $model->last_succeeded_build;
    my $hap_coverage = $build->get_metric("haploid_coverage"); #won't work on failed builds
    if($hap_coverage) {
        $data->{$sample}=$hap_coverage;
    } else {
        print STDERR "No hap coverage found for $sample\t$modelID\n";
    }

      }

      return $data;

}

sub get_map_undup_readcount {

    my $build = shift;

    my $bam_stat = Genome::Model::Tools::Sam::Flagstat->parse_file_into_hashref($build->whole_rmdup_bam_flagstat_file);
    my $map_undup_reads = $bam_stat->{'reads_mapped'} - $bam_stat->{'reads_marked_duplicates'};

    return $map_undup_reads;

}

sub getROI {
  my $file = shift;
  my @ROIs=();
  open(FILE, $file) or die "Unable to open the file $file due to $!";
  while(<FILE>) {
    chomp;
    my($chr,$start,$stop) = split(/\t/,$_);
    my $roi = "$chr:${start}-${stop}";
    push(@ROIs,$roi);
  }
  close FILE;

  return @ROIs;
}
