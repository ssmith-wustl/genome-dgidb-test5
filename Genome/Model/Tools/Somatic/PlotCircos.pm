package Genome::Model::Tools::Somatic::PlotCircos;

use warnings;
use strict;

use Genome;
use Carp;
use IO::File;
use Genome::Utility::FileSystem;
use Cwd qw( abs_path getcwd );
use File::Basename;

class Genome::Model::Tools::Somatic::PlotCircos{
    is => 'Command',
    has_optional => [
        cna_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'Windowed copy number from sequence data',
        },
        tier1_lc_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier1 variants',
        },
        tier1_hc_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier1 variants in SOMATIC format if you not need labels',
        },
         tier1_hclabel_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier1 variants in ANNOTATION format if you want them labelled. somatic format BAD',
        },
        tier1_rchclabel_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier1 recurrent variants in ANNOTATION format if you want them labelled. somatic format BAD',
        },
        ctx_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier3 variants',
        },
        itx_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier3 variants',
        },
        del_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier3 variants',
        },
        ins_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier3 variants',
        },
        inv_file => {
            is  => 'String',
            is_input  => 1,
            doc => 'The list of tier3 variants',
        },
        output_file => {
            is => 'String',
            is_input => 1,
            is_output => 1,
            doc=> 'The output png.',
        },
        config_file => {
            is => 'String',
            doc => 'circos config file',
        },
        output_dir => {
            is => 'String',
            doc => 'output to dump circos files instead of temp',
        },
        #private variables
        _cna_circos_file => {
            is => 'String',
        },
        _ideogram_file => {
            is => 'String',
        },
        _circos_config_dir => {
            is => 'String',
        },
        _tier1_hc_circos_file => {
            is  => 'String',
        },
         _tier1_hclabel_circos_file => {
            is  => 'String',
        },
         _tier1_rchclabel_circos_file => {
            is  => 'String',
        },
        _tier1_lc_circos_file => {
            is  => 'String',
        },
        _ctx_circos_file => {
            is  => 'String',
        },
        _itx_circos_file => {
            is  => 'String',
        },
        _ins_circos_file => {
            is  => 'String',
        },
        _inv_circos_file => {
            is  => 'String',
        },
        _del_circos_file => {
            is  => 'String',
        },
    ],
};

sub help_brief {
    "make circos graph",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools somatic plot-circos...    
EOS
}

sub help_detail {                           
    return <<EOS 
makes a circos graph 
EOS
}

sub execute {
    my $self = shift;
    $DB::single=1;
        
    #test files 
    my $cna_fh;
    
    if($self->cna_file) {
        $cna_fh = IO::File->new($self->cna_file,"r");

        unless($cna_fh) {
            $self->error_message("Couldn't open " . $self->cna_file);
            return;
        }
    }

    #copynumber information
    my ($cna_circos_fh, $cna_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_cna_circos_file($cna_temp_file);
    #First convert everything to Circos format.

    #write out converted cna file
    $self->convert_cna_file($cna_fh,$cna_circos_fh);
    $cna_fh->close if($cna_fh);
    $cna_circos_fh->close;

    #convert and write out the tier1 hc sites
    my $hc_fh;
    if($self->tier1_hc_file) {
        $hc_fh = IO::File->new($self->tier1_hc_file,"r");
        unless($hc_fh) {
            $self->error_message("Couldn't open " . $self->tier1_hc_file);
            return;
        }
    }
    my ($hc_circos_fh, $hc_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_tier1_hc_circos_file($hc_temp_file);
    
    $self->convert_sniper_file($hc_fh, $hc_circos_fh);
    $hc_fh->close if $hc_fh;
    $hc_circos_fh->close;
    #chris harris added this to do labels 
    my $hclabel_fh;
    if($self->tier1_hclabel_file) {
        $hclabel_fh = IO::File->new($self->tier1_hclabel_file,"r");
        unless($hclabel_fh) {
            $self->error_message("Couldn't open " . $self->tier1_hclabel_file);
            return;
        }
    }
    my ($hclabel_circos_fh, $hclabel_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_tier1_hclabel_circos_file($hclabel_temp_file);
    
    $self->convert_anno_file($hclabel_fh, $hclabel_circos_fh);
    $hclabel_fh->close if $hclabel_fh;
    $hclabel_circos_fh->close;
    #end chris harh;
    #for labeling recurrent Tier1s special!!
    my $rchclabel_fh;
    if($self->tier1_rchclabel_file) {
        $rchclabel_fh = IO::File->new($self->tier1_rchclabel_file,"r");
        unless($rchclabel_fh) {
            $self->error_message("Couldn't open " . $self->tier1_rchclabel_file);
            return;
        }
    }
    my ($rchclabel_circos_fh, $rchclabel_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_tier1_rchclabel_circos_file($rchclabel_temp_file);
    
    $self->convert_anno_file($rchclabel_fh, $rchclabel_circos_fh);
    $rchclabel_fh->close if $rchclabel_fh;
    $rchclabel_circos_fh->close;
    #now do lc tier1 mutations
    my $lc_fh;
    if($self->tier1_lc_file) {
        $lc_fh = IO::File->new($self->tier1_lc_file,"r");
        unless($lc_fh) {
            $self->error_message("Couldn't open " . $self->tier1_lc_file);
            return;
        }
    }
    my ($lc_circos_fh, $lc_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_tier1_lc_circos_file($lc_temp_file);
    
    $self->convert_sniper_file($lc_fh, $lc_circos_fh);
    $lc_fh->close if $lc_fh;
    $lc_circos_fh->close;

    #now do SV
    my $ctx_fh;
    if($self->ctx_file) {
        $ctx_fh = IO::File->new($self->ctx_file,"r");
        unless($ctx_fh) {
            $self->error_message("Couldn't open " . $self->ctx_file);
            return;
        }
    }
    my ($ctx_circos_fh, $ctx_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_ctx_circos_file($ctx_temp_file);
    
    $self->convert_breakdancer_file($ctx_fh, $ctx_circos_fh, "dgreen");
    $ctx_fh->close if $ctx_fh;
    $ctx_circos_fh->close;

    my $itx_fh;
    if($self->itx_file) {
        $itx_fh = IO::File->new($self->itx_file,"r");
        unless($itx_fh) {
            $self->error_message("Couldn't open " . $self->itx_file);
            return;
        }
    }
    my ($itx_circos_fh, $itx_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_itx_circos_file($itx_temp_file);
    
    $self->convert_breakdancer_file($itx_fh, $itx_circos_fh, "lgreen");
    $itx_fh->close if $itx_fh;
    $itx_circos_fh->close;
    
    my $ins_fh;
    if($self->ins_file) {
        $ins_fh = IO::File->new($self->ins_file,"r");
        unless($ins_fh) {
            $self->error_message("Couldn't open " . $self->ins_file);
            return;
        }
    }
    my ($ins_circos_fh, $ins_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_ins_circos_file($ins_temp_file);
    
    $self->convert_breakdancer_file($ins_fh, $ins_circos_fh, "orange");
    $ins_fh->close if $ins_fh;
    $ins_circos_fh->close;
    
    my $inv_fh;
    if($self->inv_file) {
        $inv_fh = IO::File->new($self->inv_file,"r");
        unless($inv_fh) {
            $self->error_message("Couldn't open " . $self->inv_file);
            return;
        }
    }
    my ($inv_circos_fh, $inv_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_inv_circos_file($inv_temp_file);
    
    $self->convert_breakdancer_file($inv_fh, $inv_circos_fh, "purple");
    $inv_fh->close if $inv_fh;
    $inv_circos_fh->close;

    my $del_fh;
    if($self->del_file) {
        $del_fh = IO::File->new($self->del_file,"r");
        unless($del_fh) {
            $self->error_message("Couldn't open " . $self->del_file);
            return;
        }
    }
    my ($del_circos_fh, $del_temp_file) = Genome::Utility::FileSystem->create_temp_file();
    $self->_del_circos_file($del_temp_file);
    
    $self->convert_breakdancer_file($del_fh, $del_circos_fh, 'dblue');
    $del_fh->close if $del_fh;
    $del_circos_fh->close;
    
    ####ADDED FOR BRC1 ONLY####
    
    #write out config files etc 
    my ($ideogram_fh, $ideogram_path) = Genome::Utility::FileSystem->create_temp_file($self->ideogram_file_name);
    print $ideogram_fh $self->ideogram_file_contents;
    $ideogram_fh->close;
    $self->_ideogram_file($ideogram_path);

    my ($config_fh, $config_path) = Genome::Utility::FileSystem->create_temp_file($self->config_file_name);
    print $config_fh $self->config_file_contents;
    $config_fh->close;

    `circos -conf $config_path`;
   
    my $circos_output= $self->output_file;
    my $circos_smallest = $self->output_file . "920x920.png";
    my $circos_small = $self->output_file . "3000x3000.png";
    `convert $circos_output -resize 3000x3000 -interpolate bicubic -quality 100 $circos_small`;
    `convert $circos_small -resize 3000x3000 -interpolate bicubic -quality 100 $circos_smallest`;
     
    #Then graph. Done!
    return 1;
}

sub convert_sniper_file {
    my ($self,$sniper_fh, $output_fh) = @_;
    if($sniper_fh) { 
        unless($sniper_fh->opened && $output_fh->opened) {
            return;
        }

        my $label = 0; #this will give each SNP a unique label
        while(my $line = $sniper_fh->getline) {
            $label++;
            chomp $line;
            my ($chr,$start, @rest) = split /\t/, $line;

            print $output_fh "hs$chr $start $start\n";
        }
    }
    return 1;
}

#==================chris harris added this===========
sub convert_anno_file {
    my ($self,$sniper_fh, $output_fh) = @_;
    if($sniper_fh) { 
        unless($sniper_fh->opened && $output_fh->opened) {
            return;
        }

        my $label = 0; #this will give each SNP a unique label
        while(my $line = $sniper_fh->getline) {
            $label++;
            chomp $line;
            my ($chr,$start, $stop, $ref, $var, $mut, $gene, $transcript, $source, $version, $strand, $dunno, $type, $c_position, $amino_acid_change, @rest) = split /\t/, $line;
            $DB::single=1;
            my $label = '';
            $amino_acid_change =~ s/p\.//;
            $label = "$gene\[$amino_acid_change\]" if $gene;
            print $output_fh "hs$chr $start $start $label\n";
        }
    }
    return 1;
}
#--------------------------------------------------


sub convert_breakdancer_file {
    my ($self, $breakdancer_fh, $output_fh, $color) = @_;
    if($breakdancer_fh) { 
        unless($breakdancer_fh->opened && $output_fh->opened) {
            return;
        }
        my $color_label;
        my $label = 0; #this will give each SV a unique label
        while(my $line = $breakdancer_fh->getline) {
            $label++;
            chomp $line;
            my ($chr1,$breakpoint1,$orientation1,$chr2,$breakpoint2,$orientation2,$type,$size, $score,) = split /\t/, $line;
            if($score == 99) {
                $color_label=$color;
            }
            else {
                $color_label = $color . "_N$score";
            }
            print $output_fh "$type$label\ths$chr1\t$breakpoint1\t$breakpoint1\tcolor=$color_label\n";
            print $output_fh "$type$label\ths$chr2\t$breakpoint2\t$breakpoint2\tcolor=$color_label\n";
        }
    }
    return 1;
}

sub convert_cna_file {
    my ($self, $map2cna_fh, $output_fh) = @_;
    if($map2cna_fh) {
        unless($map2cna_fh->opened && $output_fh->opened) {
            return;
        }

        while(my $line = $map2cna_fh->getline) {
            chomp $line;
            next if $line =~ /^#|^CHR/i; #ignore comment lines and header line
            my @fields = split /\t/, $line;
            printf $output_fh "hs%s\t%d\t%d\t%f\n",$fields[0], $fields[1],$fields[1],$fields[-1]; #chr\tstart\tend\tdifference between tumor and normal\n
        }
    }
    return 1;
}

sub ideogram_file_name {
    return "pipeline_ideogram.conf";
}

sub ideogram_file_contents {
    #This just stores the contents of the pipeline's ideogram configuration file with the source. It could be excised and stored in an appropriate
    #central location
    return <<IDEOGRAM;
###
### ideogram.conf
###

<ideogram>

<spacing>

default = 10u

</spacing>

# thickness (px) of chromosome ideogram
thickness        = 300p
stroke_thickness = 2
# ideogram border color
stroke_color     = black
fill             = yes
# the default chromosome color is set here and any value
# defined in the karyotype file overrides it
fill_color       = black

# fractional radius position of chromosome ideogram within image
radius         = 0.8r
show_label     = yes
label_font     = condensedbold
label_center= yes
label_radius = (dims(ideogram,radius_outer)+dims(ideogram,radius_inner))/2
label_size     = 80 

# cytogenetic bands
band_stroke_thickness = 2

# show_bands determines whether the outline of cytogenetic bands
# will be seen
show_bands            = no 
# in order to fill the bands with the color defined in the karyotype
# file you must set fill_bands
fill_bands            = no

band_transparency     = 1

</ideogram>
IDEOGRAM
    
}

sub config_file_name {
    my $self = shift;
    return "pipeline.conf";
}

sub config_file_contents {
    my $self = shift;
    #set up filenames here
    my $ideogram = $self->_ideogram_file;
    my $cna = $self->_cna_circos_file;
    my $hc = $self->_tier1_hc_circos_file;
    my $lc = $self->_tier1_lc_circos_file;
    my $ctx = $self->_ctx_circos_file;
    my $itx = $self->_itx_circos_file;
    my $ins = $self->_ins_circos_file;
    my $inv = $self->_inv_circos_file;
    my $del = $self->_del_circos_file;
    my $hc_label=$self->_tier1_hclabel_circos_file;
    my $rchc_label=$self->_tier1_rchclabel_circos_file;
    
    my $file = $self->output_file;
    my $dir;
    #Store Cwd if necessary
    if($file) {
        ($file,$dir) = fileparse($file); #circos will change the path of this file
        $dir = abs_path($dir);
    }
    else {
        $file = 'test.png';
        $dir = getcwd();
    }
        

    return <<CONF;
###
### gt somatic plot-circos configuration file
###

<colors>
<<include /gsc/pkg/bio/circos/installed/etc/colors.conf>>
</colors>

<fonts>
<<include /gsc/pkg/bio/circos/installed/etc/fonts.conf>>
</fonts>

<<include $ideogram>>

karyotype = /gsc/pkg/bio/circos/installed/data/7/karyotype.human.colorbychr.txt

<image>

background = white
dir = $dir 
file  = $file 
24bit = yes
auto_alpha_colors = yes
auto_alpha_steps  = 98 
png = yes
#svg = yes
# radius of inscribed circle in image
radius         = 5400p
# by default angle=0 is at 3 o'clock position
angle_offset   = -90
#angle_orientation = counterclockwise

auto_alpha_colors = yes
auto_alpha_steps  = 5
</image>

chromosomes_units           = 1000000

chromosomes_display_default = yes

anglestep       = 0.5
minslicestep    = 10
beziersamples   = 40
debug           = no
warnings        = no
imagemap        = no

units_ok = bupr
units_nounit = n

<plots>
<plot>
type             = text
color            = black
file       = $hc_label

r0 = 1r
r1 = 1.2r

label_snuggle             = yes
# shift label up to its height in pixels in the angular direction
max_snuggle_distance      = 50r
snuggle_sampling          = 2
snuggle_tolerance         = 1r
snuggle_link_overlap_test = yes
snuggle_link_overlap_tolerance = 1p
snuggle_refine            = yes


show_links     = yes
link_dims      = 6p,6p,70p,6p,6p
link_thickness = 9p
link_color     = black

label_size   = 90p
label_font   = condensed

padding  = 12p
rpadding = 12p

</plot>

<plot>
type             = text
color            = red
file       = $rchc_label

r0 = 1r
r1 = 1.2r

label_snuggle             = yes
# shift label up to its height in pixels in the angular direction
max_snuggle_distance      = 50r
snuggle_sampling          = 2
snuggle_tolerance         = 1r
snuggle_link_overlap_test = yes
snuggle_link_overlap_tolerance = 1p
snuggle_refine            = yes


show_links     = yes
link_dims      = 6p,6p,70p,6p,6p
link_thickness = 9p
link_color     = red

label_size   = 90p
label_font   = condensed

padding  = 12p
rpadding = 12p

</plot>


<plot>

 show  = yes
 type  = scatter
 file  = $cna 
 glyph = circle
 glyph_size = 8
 fill_color = black
 stroke_color = black
 stroke_thickness = 1
 min   = -4 
 max   = 4 
 r0    = 0.74r
 r1    = .94r
 
 axis           = yes
 axis_color     = lgrey
 axis_thickness = 2
 axis_spacing   = 0.001
</plot>



</plots>


<highlights>

<highlight>
fill_color = dred 
stroke_color = dred
stroke_thickness = 15
file       = $hc 
r0         = .95r
r1         = .99r
</highlight>

<highlight>
fill_color = lred 
stroke_color = lred
stroke_thickness = 15
file       = $lc 
r0         = .95r
r1         = .99r
</highlight>

</highlights>

<links>

z      = 10
radius = 0.7r
bezier_radius = 0.1r

<link deletions>
color = dblue
thickness = 15
radius = 0.73r
bezier_radius = .7r
crest = 10 
file = $del 
</link>

<link inversions>
color = purple
thickness = 15
radius = 0.73r
bezier_radius = .7r
crest = 10
file = $inv 
record_limit = 10000
</link>

<link insertions>
color = orange 
thickness = 15
radius = 0.73r
bezier_radius = .7r
crest = 10
file = $ins 
record_limit = 100000
</link>

<link translocations>
color = dgreen 
thickness = 15
radius = 0.73r
bezier_radius = .7r
crest = 1
file = $ctx 
</link>

<link intratranslocations>
color = lgreen 
thickness = 5
radius = 0.73r
bezier_radius = .7r
crest = 2
file = $itx 
</link>

</links>
CONF
}
