package Genome::Model::Command::Export::ReviewDirectory;

use strict;
use warnings;

use Genome;

use Command;
use Data::Dumper;
use File::Temp;
use IO::File;
use Genome::Model::Tools::Maq::Map::Reader;

class Genome::Model::Command::Export::ReviewDirectory
{
    is => 'Command',                       
    has => 
    [ 
        model_name => 
        {
            type => 'String',
            is_optional => 0,
            doc => "Model name we're working on",
        },
        #snp_file =>
        #{
        #    type => 'String',
        #    is_optional => 0,
        #    doc => "File of variants",    
        #},
        review_list =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Name of review list",
        },
        output_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Directory to generate Manual Review reports",    
        },
        ref_seq_id =>
        {
            type => 'String',
            is_optional => 1,
            doc => "Ref seq id",    
        },
        library_name =>
        {
            type => 'String',
            is_optional => 1,
            doc => "Library name",    
        },
    ], 
};

############################################################

sub help_brief {   
    return;
}

sub help_synopsis { 
    return;
}

sub help_detail {
    return <<EOS 
    Creates a manual review directory from a given map list, snp file, and output dir.  This command must be run on a x64 system.
EOS
}

############################################################
my %ref_names;
sub execute { 
    my $self = shift;
$DB::single = 1;
    my $out_dir = $self->output_dir;
    my $review_list_name = $self->review_list;
    my $model_name = $self->model_name;
    my $ref_seq_id = $self->ref_seq_id;
    my $library_name = $self->library_name;
    
    #create snp file
    my $review_list = Genome::VRList->get(name => $review_list_name);
    #my @review_list_members = Genome::VRListMember->get(list_id => $review_list->list_id);
    my @variant_review_detail = $review_list->details;#map { Genome::VariantReviewDetail->get(id => $_->member_id) } @review_list_members;
    `mkdir -p $out_dir`;
    my $snps = "$out_dir/snps";
    my $vrd = "$out_dir/variant_review_details";
    my $fh = IO::File->new(">$snps");
    foreach my $det (@variant_review_detail)
    {
        print $fh $det->chromosome."\t".$det->start_position."\n";
    }
    $fh->close;
    
    #create detail file
    $fh = IO::File->new(">$vrd");
    my @props =sort { 
        $a->property_name cmp $b->property_name
    } grep {
        $_->column_name ne ''
    } Genome::VariantReviewDetail->get_class_object->all_property_metas;
    my @column_names = map { $_->column_name } @props;
    my @property_names = map { $_->property_name } @props;
    #print header
    my $header = join "|",@column_names;
    print $fh $header,"\n";
    #print rows
    foreach my $det (@variant_review_detail)
    {
        my @props = map { $det->$_||'' } @property_names;
        my $line = join "|",@props;print $line,"\n";
        print $fh $line,"\n";
    }
    $fh->close;    
    
    my $model;
    #if($build_id)
    #{
        ($model) = Genome::Model->get(name => $model_name);
    #}
    #else
    #{
    #    ($model) = Genome::Model->get(name => $model_name);
    #}
    my $build = $model->last_complete_build;
    my $build_dir = $build->data_directory;
    return unless $model;
    print $model->name,"\n";
    
    my @maplists = $model->maplist_file_paths(ref_seq_id => $ref_seq_id, library_name => $library_name);
    
    unless (@maplists) {
        $self->error_message("Failed to find maplists!");
        return;
    }
    
    
    my $out_fh = File::Temp->new(UNLINK => 1);
    unless ($out_fh) {
        $self->error_message("Can not create temp file.\n");
        return;
    }
    my @maps;
    for my $maplist (@maplists) {
        my $in_fh = IO::File->new($maplist,'r');
        unless($in_fh) {
            $self->error_message("Can not open file for reading '$maplist':  $!");
            return;
        }
        @maps = <$in_fh>;
        $in_fh->close;
        print $out_fh @maps;
    }
    $self->sort_snps($snps,$maps[0]);
    
    return Genome::Model::Tools::ManualReview::CreateDirectory->execute(map_list => $out_fh->filename, snp_file => $snps, output_dir => $out_dir);
}
############################################################
sub comp 
{

	my ($a1, $a2) = split /\W+/,$a;
	my ($b1, $b2) = split /\W+/,$b;
	if($a1 eq $b1) 
	{
		return $a2 <=> $b2;
	}
	else
	{
		return $ref_names{$a1} <=> $ref_names{$b1};
	}
}
sub grp {
    my ($line) = @_; 
    print "line is:",$line;
    my ($name) = split (/\W+/,$line);
    print "name is:$name"."a\n";
    return exists $ref_names{$name}; 
}

sub sort_snps 
{
    my ($self, $snp_file, $map_file_name) = @_;
    my @ref_name;
    chomp $map_file_name;
    #print "map file is $map_file_name\n";
    my $reader = Genome::Model::Tools::Maq::Map::Reader->new;
    $reader->open($map_file_name);
    my $header = $reader->read_header();
    @ref_name = @{$header->{ref_name}};
    
    my $i = 0;
    %ref_names = map { $i++; $_, $i-1;   } @ref_name;
    #print join ("\n",@ref_name,"\n");
    #print join ("\n",keys %ref_names,"\n");
    my $fh=IO::File->new($snp_file);
    my $out = File::Temp->new(UNLINK => 0);
    unless ($out) {
        $self->error_message("Can not create temp file.\n");
        return;
    }
    

    my @lines = <$fh>;
    print scalar @lines, "\n";

    @lines = grep {  grp($_);  } @lines;
    print scalar @lines, "\n";
    print "loaded\n";
    @lines = sort comp @lines;
    print "done sorting\n";
    print $out @lines;
    print "done printing\n";
    my $filename = $out->filename;
    $out->close;
    $fh->close;
    `/bin/mv $filename $snp_file`;    
}


1;

