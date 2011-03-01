package Genome::Model::Tools::Analysis::DetectRecurrence;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use FileHandle;

class Genome::Model::Tools::Analysis::DetectRecurrence {
    is => 'Command',
#    has => [
#    model_group => { 
#        type => 'String',
#        is_optional => 0,
#        doc => "name of the model group to process",
#   },
#    ]
};

sub execute {
        my $self=shift;
        $DB::single = 1;
    
        my $major_group="TCGA-AML-WashU-SomaticCapture"; #model group ID: 3204 (exome)
        my %majorgroup_var_hash=%{&build_var_hash($major_group, "exome")};
        my %majorgroup_detect_hash=%{&build_detect_hash(\%majorgroup_var_hash)};

        my $second_group="AML_M1/M3_validated";
        my $file_names="/gscmnt/sata423/info/medseq/analysis/AML*/curated*/varScan.output.snp.targeted.tier1.snvs.pass_strand.post_filter.curated.anno";
        my %secondgroup_var_hash=%{&build_var_hash_from_files($file_names)};
        my %secondgroup_detect_hash=%{&build_detect_hash(\%secondgroup_var_hash)};

        &report_recur(\%majorgroup_detect_hash,$major_group, \%secondgroup_detect_hash,$second_group);

        return 1;

}

1;

sub help_brief {
    "detect recurrence among model groups/files"
}

sub help_detail {
    <<'HELP';
Hopefully this script will detect recurrence within first model group, and detect overlap between the second model group
HELP
}

sub build_var_hash_from_files
{
        my ($file_name)=@_;
        my @files=glob($file_name);
        my %variants;
        foreach my $file (@files)
        {
                my @parts=split/\//, $file;
                my $project_name=$parts[6];
                my $fh=new FileHandle($file);
                while(<$fh>)
                {
                        chomp;
                        my ($chr,$start,$stop,$ref,$var,$mut_type,$gene,@others)=split/\t/, $_;
                        next if ($gene eq "-");
               
                        my $pos=$chr."_".$start."_".$stop;
                        
                        $variants{$gene}{project_name} .= "$project_name;";
                        $variants{$gene}{lines} .= "$_;";
                }
        }
        return \%variants;
}

sub report_recur
{
        my ($first_refhash,$major_group, $sec_refhash,$second_group)=@_;
        my %first_hash=%{$first_refhash};
        my %sec_hash=%{$sec_refhash}; 
        my $first_sample_num;
        my $sec_sample_num;
        my $total_num;
        open OUT, ">summary.recurrence.csv";
        print OUT "Gene\tTotal\t$major_group\t$second_group\n";
        foreach my $gene (sort keys %sec_hash)
        {
                next unless (defined $first_hash{$gene});
                
                my @first_samples=sort keys %{$first_hash{$gene}};
                $first_sample_num=@first_samples;
                foreach my $first_sample (@first_samples)
                {
                        my @lines=@{$first_hash{$gene}{$first_sample}};
                        foreach my $line (@lines)
                        {
                                print "$gene\t$first_sample\t$line\n";
                        }
                }
                
                my @sec_samples=sort keys %{$sec_hash{$gene}};
                $sec_sample_num=@sec_samples;
                foreach my $sec_sample (@sec_samples)
                {
                        my @lines=@{$sec_hash{$gene}{$sec_sample}};
                        foreach my $line (@lines)
                        {
                                print "$gene\t$sec_sample\t$line\n";
                        }
                }
                $total_num=$first_sample_num+$sec_sample_num;   
                print OUT "$gene\t$total_num\t$first_sample_num\t$sec_sample_num\n";             
        }
        
}

sub build_var_hash
{
        my ($model_group, $type)=@_;
        my %pos_hash;
        my %variants;
        my ($indel_anno, $snp_anno, $t1_hc_snp, $t1_snp, $t1_indel);
        my @builds = Genome::ModelGroup->get(name => $model_group)->builds; 
        for my $build (@builds) 
        {
            my $model=$build->model;
            my $project_name=$model->name;
            my $data_directory = $build->data_directory; 
            #print "$data_directory\t$project_name\n";
            $indel_anno="$data_directory/ani_annotated_indel.csv" if ($type eq "somatic");
            $snp_anno="$data_directory/anv_annotated_snp.csv" if ($type eq "somatic");
            $t1_hc_snp="$data_directory/hc1_tier1_snp_high_confidence.csv" if ($type eq "somatic");
            $t1_snp="$data_directory/t1v_tier1_snp.csv" if ($type eq "somatic");
            $t1_indel="$data_directory/t1i_tier1_indel.csv" if ($type eq "somatic");
            
            $snp_anno="$data_directory/annotation.somatic.snp.transcript" if ($type eq "exome");
            $t1_hc_snp="$data_directory/merged.somatic.snp.filter.novel.tier1.hc" if ($type eq "exome");
            
            my $t1_hc_snp_fh = IO::File->new($t1_hc_snp,"r") or die "Can't open $t1_hc_snp\n";
            while(<$t1_hc_snp_fh>)
            {
                chomp;
                my ($chr,$start,$stop, @others) = split /\t/;
                my $pos = $chr."_".$start."_".$stop;
                $pos_hash{$pos}=1;
            }
            $t1_hc_snp_fh->close;
            
            my $snp_anno_fh=IO::File->new($snp_anno,"r") or die "Can't open $snp_anno\n";
            
            while(<$snp_anno_fh>)
            {
                chomp;
                my ($chr,$start,$stop,$ref,$var,$mut_type,$gene,@others)=split/\t/, $_;
                next if ($gene eq "-");
                #next unless ($gene eq "uc010lft.1");
                my $pos=$chr."_".$start."_".$stop;
                next unless (defined ($pos_hash{$pos}));
                $variants{$gene}{project_name} .= "$project_name;";
                $variants{$gene}{lines} .= "$_;";
             }
             $snp_anno_fh->close;
        }   
        return \%variants;
} 

 sub build_detect_hash
 {
        my ($var_refhash)=@_;
        my %variants=%{$var_refhash};
        my %detect_gene;  #detect_gene{gene}{sample}=line
        foreach my $gene (sort keys %variants) 
        {
            my @samples_in = split /;/, $variants{$gene}{project_name};
            my @lines_in = split /;/, $variants{$gene}{lines};
            #my %samples = map {$_ => 1} @samples_in;
            
                #print "$gene:\n";
                
                foreach my $sample (@samples_in) 
                {
                    my $line = shift @lines_in;
                    
                    if (defined $detect_gene{$gene}{$sample})
                    {
                        unless (grep /^$line$/, @{$detect_gene{$gene}{$sample}})
                        {
                                push @{$detect_gene{$gene}{$sample}}, $line;
                        }
                    }
                    else
                    {
                        my @arr=($line);
                        $detect_gene{$gene}{$sample}=\@arr;
                    }
                    
                    #print "\t$line\t$sample\n";
                }
        }
        return \%detect_gene;
 }

