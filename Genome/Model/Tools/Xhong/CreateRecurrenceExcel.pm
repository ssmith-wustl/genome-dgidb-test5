package Genome::Model::Tools::Xhong::CreateRecurrenceExcel;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Spreadsheet::WriteExcel;
use Sort::Naturally qw( nsort );

# example: perl -I /gscuser/xhong/svn/perl_modules `which gmt` xhong create-recurrence-excel -model-group "PCGP-somatic" --analysis-dir /gscuser/xhong/SJC/recurrent > /gscuser/xhong/SJC/recurrent/bam_file_list.tx

class Genome::Model::Tools::Xhong::CreateRecurrenceExcel {
    is => 'Command',
    has => [
    model_group => { 
        type => 'String',
        is_optional => 0,
        doc => "name of the model group to process",
    },
        analysis_dir => {
        type => 'String',
        is_optional => 0,
        doc => "Directory to use for maplists and mapcheck output",
    },
    ]
};


sub execute {
	my $self=shift;
    	$DB::single = 1;
    	my $dir=$self->analysis_dir;
    	my @models;
    	my $group = Genome::ModelGroup->get(name => $self->model_group);
    	unless($group) {
    	    $self->error_message("Unable to find a model group named " . $self->model_group);
    	    return;
    	}
    	push @models, $group->models;
    	my %lines;
    	my %hc1;
    	my %recurrent;
    	my %recurrent_nosilent;
    	my %recurrent_list;
    	my %recurrent_nosilent_list;
	my %tumor_bam;
	my %normal_bam;
	
    	foreach my $model (@models) {
    		my $subject_name = $model->subject_name;
 #   print "$subject_name\t";
        	unless($model->type_name eq 'somatic') {
            		$self->error_message("This build must be a somatic pipeline build");
            		return;
        	}

	        my $build = $model->last_succeeded_build;
	        unless (defined($build)) {
        		$self->error_message("Unable to find succeeded build for model ".$model->id);
        		return; #next;
        	}
        	my $model_id = $build->model_id;
        	my $build_id = $build->build_id;
        # find bam files of somatic build and its common name & cancer type	
        	my $tumor_wgs_bam = $build->tumor_build->whole_rmdup_bam_file;
                my $normal_wgs_bam = $build->normal_build->whole_rmdup_bam_file;
	        my $tumor_common_name = $build->tumor_build->model->subject->source_common_name;
        	my $tumor_type = $build->tumor_build->model->subject->common_name;
        	my $normal_common_name = $build->normal_build->model->subject->source_common_name;
        	my $normal_type = $build->normal_build->model->subject->common_name;

		$tumor_bam{$tumor_common_name}=$tumor_wgs_bam;
		$normal_bam{$normal_common_name}=$normal_wgs_bam;
	
	#next unless($tumor_build->model->subject->sub_type !~ /M[13]/);

        	printf "%s %s: %s\n%s %s: %s\n",$tumor_common_name, $tumor_type, $tumor_wgs_bam, $normal_common_name, $normal_type, $normal_wgs_bam;

        #satisfied we should start doing stuff here
	        my $data_directory = $build->data_directory . "/";

        	unless(-d $data_directory) {
        		$self->error_message("$data_directory is not a directory");
        		return;
        	}

 #       my $indel_transcript_annotation = "$data_directory/annotate_output_indel.out";
	        my $snp_transcript_annotation = "$data_directory/upload_variants_snp_1_output.out";
        	my  %snv_tiers = (
        		"Tier1" => "$data_directory/tier_1_snp_high_confidence_file.out",
        	);

	        # if not exist, check if using new files
	        unless(-e $snp_transcript_annotation) {
        		$snp_transcript_annotation = "$data_directory/uv1_uploaded_tier1_snp.csv";
	        	%snv_tiers = (
	                	"Tier1" => "$data_directory/hc1_tier1_snp_high_confidence.csv",
        		);

	        }


        	my $common_name = $build->tumor_build->model->subject->source_common_name;
#        print "$common_name\n";

        	foreach my $tier (qw{ Tier1 }) {

            		my $snv_file = $snv_tiers{$tier};
            		my @lines;
            		@lines = `/gscuser/dlarson/bin/perl-grep-f -f $snv_file $snp_transcript_annotation`;
#            		print `wc -l $snv_file $snp_transcript_annotation`;
	                map { $_ = "$common_name\t".$_;} @lines; 
	            	push @{$lines{$tier}}, @lines;
        	}
        	print "\n";        
    	} # finish of all models

    	#write out the lines
    	my @column; my $gene; my $change; my @lines; my $m; my $n;
    	open(FH, ">$dir/PCGP_hc1.csv") or die "cannot creat such a test.csv file";
    	foreach my $tier (qw{ Tier1 }) {
    		@lines = @{$lines{$tier}};
    		foreach (@lines){ 
			@column=split/\t/, $_;
			my $sample=$column[0];
#			my $chr=$column[1];
#			my $pos=$column[2];
			$gene=$column[7];
			$change=$column[14];
	        	if (!exists $hc1{$gene}){
		       		$hc1{$gene}=$_;
			}else{
				$hc1{$gene}=$hc1{$gene}.$_;
				$recurrent{$gene}=$hc1{$gene};
				$recurrent_list{$gene}=1;
				$m++;
#				print "$m\t";
				if ($change ne "silent"){
#					my $k=$sample.".".$chr.".".$pos;
					$recurrent_nosilent{$gene}=$recurrent{$gene};
					$recurrent_nosilent_list{$gene}=1;
					$n++;
					#$file
#					print "*$n\t";
        			}
        		}
        	}
        	print FH @lines;
	}
    	close FH;
    	my@m=(keys%recurrent_list);
    	my@n=(keys%recurrent_nosilent_list);
	print "recurrent $#m\n";
	print "nosilent $#n\n";
    	open(FH, ">$dir/PCGP_hc1_recurrent.csv") or die "cannot creat such a test_recurrent.csv file";
    	foreach my $key (keys %recurrent_list){
    		print FH $recurrent{$key};
    	}
    	close FH;
    
    	open(FH, ">$dir/PCGP_hc1_recurrent_nonsilent.csv") or die "cannot creat such a test_recurrent_nonsilent.csv file";
    	foreach my $key (keys %recurrent_nosilent_list){
        	print FH $recurrent_nosilent{$key};
    	}
    	close FH;
    	
    	
    
#    	my $output_file_name = "Summary.predicted.xls";

#    	my $xls = Spreadsheet::WriteExcel->new($output_file_name) or die "Couldn't create excel file";
#    	foreach my $tier (qw{ Tier1 }) {
        #TODO detect recurrence here
#        	my $sheet = $xls->add_worksheet("$tier Predicted Variants");
#        	my $next_row_to_print = 0;
#        	my $header = shift @{$lines{$tier}};
#        	$next_row_to_print += $self->write_tabbed_output_to_sheet($sheet,$next_row_to_print,[$header]);
#        	my %recurrence;
#        	$self->find_recurrent($lines{$tier},\%recurrence);
#        	my $recurrent_by_gene_color = $xls->set_custom_color(40, 0,99,199);;
#        	my $recurrent_by_aa_color = $xls->set_custom_color(41, 255,5,5);
#        	my $recurrent_by_gene_format = $xls->add_format(bg_color => $recurrent_by_gene_color);
#        	my $recurrent_by_aa_format = $xls->add_format(bg_color => $recurrent_by_aa_color);

#        	foreach my $gene (nsort keys %recurrence) {
#        		my (@samples_in, @samples_printed);
#        	    	my @lines_in;
    #        
#        	    foreach my $aa (nsort keys %{$recurrence{$gene}}) {
#                	my @samples_in_aa = split /;/, $recurrence{$gene}{$aa}{samples};
#                	my @lines_in_aa = split /;/, $recurrence{$gene}{$aa}{lines};
#                	my %samples_aa = map {$_ => 1} @samples_in_aa;
#                	if(scalar(keys %samples_aa) > 1) {
#                    #recurrent by amino_acid
#                		$next_row_to_print += $self->write_tabbed_output_to_sheet($sheet, $next_row_to_print, \@lines_in_aa, $recurrent_by_aa_format);
#                		push @samples_printed, keys %samples_aa;
#                	}else {
#                		push @samples_in, @samples_in_aa;
#                		push @lines_in, @lines_in_aa;
#                	}
#            	}
#            	my %samples = map {$_ => 1} @samples_in, @samples_printed;
#            	if(@samples_in && scalar(keys %samples) > 1) {
#            		$next_row_to_print += $self->write_tabbed_output_to_sheet($sheet, $next_row_to_print, \@lines_in, $recurrent_by_gene_format);
#            	}
#            	else {
#              		$next_row_to_print += $self->write_tabbed_output_to_sheet($sheet, $next_row_to_print, \@lines_in);
#            	}
#        }
    return 1;
}


1;

sub help_brief {
    "Generates tier1 hc SNV table"
}

sub help_detail {
    <<'HELP';
Hopefully this script will run the ucsc annotator on indels and then tier them for an already completed somatic model. Since this is done in the data directory, the model is then reallocated.
HELP
}

sub write_tabbed_output_to_sheet {
    my ($self, $sheet, $location, $output_lines, $format) = @_;

    #process output lines into an array of arrays
    my @matrix_of_data = map {chomp $_; [split /\t/, $_];} @$output_lines;


    if($sheet) {
        if(defined $format) {
            $sheet->write_col($location,0,\@matrix_of_data,$format);
        }
        else {
            $sheet->write_col($location,0,\@matrix_of_data);
        }
        return scalar(@matrix_of_data);
    }
    else {
        return;
    }

}

sub find_recurrent {
    my ($self, $line_ref, $hash_ref) = @_;
    while( my $line = shift @$line_ref) {
        chomp $line;
        my @fields = split /\t/, $line;
        my ($gene,$aa, $sample) = @fields[6,10,11];
        my ($aa_position) = $aa =~ /p\.(\D\d+)/;
        $hash_ref->{$gene}{$aa_position}{samples} .= "$sample;";
        $hash_ref->{$gene}{$aa_position}{lines} .= "$line;";
    }
}
