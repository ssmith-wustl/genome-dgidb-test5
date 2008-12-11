package Genome::Model::Tools::ManualReview::MRGui;

use strict;
use warnings;
use Gtk2 -init;
use Gtk2::GladeXML;
use Glib;
use IO::File;
use Genome::Utility::VariantReviewListReader;



use File::Basename ('fileparse');
use base qw(Class::Accessor);
use Time::HiRes qw(usleep);
Genome::Model::Tools::ManualReview::MRGui->mk_accessors(qw(current_file g_handle re_g_handle header));

my %iub_hash = ( A => 1,
                C => 2,
                G => 3,
                T => 4,
                M => 5,
                K => 6,
                Y => 7,
                R => 8,
                W => 9,
                S => 10,
                D => 11,
                B => 12,
                H => 13,
                V => 14,
                N => 15,
);
my %rev_iub_hash = map { $iub_hash{$_},$_; } keys %iub_hash;

my %somatic_status = (WT => 1,
                      O => 2,
                      LQ => 3,
                      A => 4,
                      S => 5,
                      G => 6,
                      V => 7,
                      NC => 8,
);

my %rev_somatic_status = map { $somatic_status{$_},$_; } keys %somatic_status;


sub new 
{
    croak("__PKG__:new:no class given, quitting") if @_ < 1;
	my ($caller, %params) = @_; 
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = $class->SUPER::new(\%params);    
         
    return $self;
}

sub open_file_dialog
{
	my ($self,@parms) = @_;
	my $fc = Gtk2::FileChooserDialog->new("Open File",undef, 'open',
	'gtk-cancel' => 'cancel',
	'gtk-ok' => 'ok');
  	$fc->set_select_multiple(0);
 	my $response = $fc->run;
 	my $file = $fc->get_filename;
  	$fc->destroy;
#	$self->current_file($file);
	$self->open_file($file);
}

my %cmp_hash = (x => 30, X => 30, y => 31, Y=>31);
for(my $i=0;$i<30;$i++) { $cmp_hash{$i}=$i; }
sub chrom_sort
{
    my ($liststore, $itera, $iterb) = @_;
    my ($a1, $a2) = $liststore->get($itera,0,1);
    my ($b1, $b2) = $liststore->get($iterb,0,1);
    if($a1 eq $b1) 
	{
		return $a2 <=> $b2;
	}
	else
	{
		return $cmp_hash{$a1} <=> $cmp_hash{$b1};
	}
    
}

sub build_review_tree
{
    my ($self) = @_;
    my $handle = $self->g_handle;
    
    my $tree = $handle->get_widget("review_list");

    my @col = (Gtk2::TreeViewColumn->new_with_attributes
                        ('Chromosome', Gtk2::CellRendererText->new, text => 0),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Position', Gtk2::CellRendererText->new, text => 1),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Delete Sequence', Gtk2::CellRendererText->new, text => 2),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Insert Sequence Allele 1', Gtk2::CellRendererText->new, text => 3),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Insert Sequence Allele 2', Gtk2::CellRendererText->new, text => 4),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Genotype', Gtk2::CellRendererText->new, text => 5),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Pass Manual Review', Gtk2::CellRendererText->new, text => 6),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Manual Genotype Normal', Gtk2::CellRendererText->new, text => 7),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Manual Genotype Tumor', Gtk2::CellRendererText->new, text => 8),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Manual Genotype Relapse', Gtk2::CellRendererText->new, text => 9),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Notes', Gtk2::CellRendererText->new, text => 10),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Somatic Status', Gtk2::CellRendererText->new, text => 11),
         Gtk2::TreeViewColumn->new_with_attributes
                        ('Data Needed', Gtk2::CellRendererText->new, text => 12),
                                                
        );
    foreach (@col)
    {
        $tree->append_column($_);
    }
    
    $tree->signal_connect("row-activated", \&open_cb, $self);

    return $tree;


}

#my %hash = 
#(
#    'Chromosome' => 'chromosome',
#    'Position' => 'begin_position',
#    'Delete Sequence' => 'delete_sequence',
#    'Insert Sequence Allele 1' => 'insert_sequence_allele1',
#    'Insert Sequence Allele 2' => 'insert_sequence_allele2',
#    'Genotype' => 'genotype_iub_code',
#    'Pass Manual Review' => 'pass_manual_review',
#    'Manual Genotype Normal' => 'manual_genotype_iub_normal',
#    'Manual Genotype Tumor' => 'manual_genotype_iub_tumor',
#    'Manual Genotype Relapse' => 'manual_genotype_iub_relapse'
#);

sub db_columns{
    my @columns = ( qw/
        chromosome
        begin_position
        end_position
        variant_type
        variant_length
        delete_sequence
        insert_sequence_allele1
        insert_sequence_allele2
        genes
        supporting_samples
        supporting_dbs
        finisher_manual_review
        pass_manual_review
        finisher_3730_review
        manual_genotype_normal
        manual_genotype_tumor
        manual_genotype_relapse
        somatic_status
        notes
        /);
    return @columns;
}

sub set_project_consedrc {
    my $edit_dir =shift;
    my $rc ="$edit_dir/.consedrc";

    my $wide = 'consed.alignedReadsWindowInitialCharsWide: 120';
    my $expand = 'consed.alignedReadsWindowAutomaticallyExpandRoomForReadNames: false';

    my %rc_hash;
    my $i;
    if(-e $rc ){
        open F, $rc or warn("Failed to open consed rc ($rc).\n") and return; 
        while(<F>){
            chomp;
            $i++;
            $rc_hash{$_}=$i;
        }
        close F;

    }

    my @to_append;
    unless(exists $rc_hash{$wide}){
        push @to_append, $wide;
    }
    unless(exists $rc_hash{$expand}){
        push @to_append, $expand;
    }

    return unless @to_append;

    open F, ">>$rc" or warn("Failed to open consed rc ($rc).\n") and return; 
    for(@to_append){
        print F $_ ."\n";
    }
    close F;

    return 1;
}

sub open_consed
{
    my ($self, $proj_name) = @_;
    my $relative_target_base_pos = 300;
    my $consed= 'cs';
    my($file, $dir)= fileparse($self->current_file);
    my $suffix = '.1';
    my $edit_dir = "$dir/$proj_name/edit_dir";
    if(-e $edit_dir."/consedSocketLocalPortNumber")
    {
        unlink $edit_dir."/consedSocketLocalPortNumber";
    }
    my $pid = fork();
    if ($pid)
    {
        my $i=0;
        while(!-e $edit_dir."/consedSocketLocalPortNumber")
        {
            usleep 100;
            $i++;
            if($i>50)
            {
                warn "Timed out waiting for consed to launch.\n";
                last;
            }
        }
        unlink $edit_dir."/consedSocketLocalPortNumber";
        my @lines = `ps -C consed -o pid=`;
        
        my $line = pop @lines;
        chomp $line;        

        my (undef, $pid) = split /\s+/,$line;
        return $pid;
    }
    
    if(!defined $pid) {print "fork unsuccessful.\n"; }
    

    if( -d $edit_dir){
        chdir $edit_dir or die "can't cd to $edit_dir"; 
        my $ace1 = "$proj_name.ace$suffix";
        unless(-e $ace1){
            print "ERROR no: $ace1 ... skipping (report to apipe)\n"; 
            exit;
        }        
        set_project_consedrc($edit_dir);
        
        my $c_command= "$consed -socket 0 -ace $ace1 -mainContigPos $relative_target_base_pos &>/dev/null";

        my $rc = system($c_command);
        if($rc)
        {
            warn "Failed to launch consed.\n";
            `touch consedSocketLocalPortNumber`;
        }
    }else{
        warn("ERROR  Can't find $edit_dir ... skipping (report to sabbott)\n");
    }
    exit;
    
}

sub get_col_order
{
    my ($self) = @_;
    my $header = $self->header;
    my @vis_cols = (
        'chromosome',
        'begin_position',
        'delete_sequence',
        'insert_sequence_allele1',
        'insert_sequence_allele2',
        'genotype_iub_code',
        'pass_manual_review',
        'manual_genotype_iub_normal',
        'manual_genotype_iub_tumor',
        'manual_genotype_iub_relapse',
        'notes',
        'somatic_status',
        'data_needed',
    );
    my %vis_cols = map { $_,1; } @vis_cols;
    
    foreach my $col (@$header)
    {
        push @vis_cols, $col unless(exists $vis_cols{$col});    
    }
    return @vis_cols;
}

sub open_file
{
	my ($self,$file) = @_;

	return unless (-e $file);
	$self->current_file($file);    

    my $handle = $self->g_handle;
    my $tree = $handle->get_widget("review_list");

    my $list_reader = Genome::Utility::VariantReviewListReader->new($self->current_file, '|');
    $self->header($list_reader->{separated_value_reader}->headers);
     
    my @col_order = $self->get_col_order(@{$self->header});
    my $col_count = scalar @col_order;
    my $model = Gtk2::ListStore->new(('Glib::String')x$col_count);
    $tree->set_model($model);
    $model->set_sort_func (0, \&chrom_sort);
    while (my $line_hash = $list_reader->next_line_data())
    {
        last unless $line_hash;
        if ($line_hash->{header}) { print $line_hash->{header},"\n"; }
        next if $line_hash->{header};
        my $iter = $model->append;

        for(my $i = 0;$i<@col_order;$i++)
        {
            $model->set($iter,
            $i => delete $line_hash->{$col_order[$i]});
        }            
    }
    $model->set_sort_column_id(0,'GTK_SORT_ASCENDING');
}

sub open_cb
{
	my ($tree, $mpath, $col, $self)=@_;
    
    $self->on_review_button_clicked;    
}

sub save_file
{
    my ($self) = @_;
    my $fh = IO::File->new(">".$self->current_file);
    my @col_order = $self->get_col_order;

    my $tree = $self->g_handle->get_widget("review_list");
    my $model = $tree->get_model;
    my $header = join '|',@col_order;
    $header .= "\n";
    print $fh $header;
    my $iter = $model->get_iter_first;
    do
    {   
        my @cols = $model->get($iter);
        my $row = join '|',@cols;
        $row .= "\n";
        print $fh $row;    
    }
    while($iter = $model->iter_next($iter));
    
    $fh->close;
}

sub on_save_file
{
	my ($self) = @_;
	
	unless(defined $self->current_file)
	{
		$self->save_file_as_dialog;
	}
	if(defined $self->current_file)
	{
		$self->save_file;
	}	
}

sub save_file_as_dialog
{
	my ($self) = @_;
	my $fc = Gtk2::FileChooserDialog->new("Save File As",undef, 'save',
	'gtk-cancel' => 'cancel',
	'gtk-ok' => 'ok');
  	$fc->set_select_multiple(0);
	if($self->current_file)
	{
  		$fc->set_current_folder ($self->current_file);
 	}
	my $response = $fc->run;
 	my $file = $fc->get_filename;
  	$fc->destroy;
	$self->current_file($file);	
}

sub on_save_file_as
{
	my ($self) = @_;
	
	$self->save_file_as_dialog;
	if(defined $self->current_file)
	{
		$self->save_file;
	}
}

sub on_re_ok
{
    my ($button, $data) = @_;
    my ($self,$glade,$review_editor,$model, $row) = @{$data};
    my %pf = (Pass => 1, Fail => 2);
    my %rpf = (1 => 'Pass', 2 => 'Fail');
    my %dn = (Yes => 1, No => 2);
    my %rdn = (1 => 'Yes', 2 => 'No');
    
    my $cb = $glade->get_widget('re_genotype');
    my $active = $cb->get_active();
    $model->set($row,5 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};
    $cb = $glade->get_widget('re_passfail');
    $active = $cb->get_active();
    $model->set($row,6 => $rpf{$active}) if exists $rpf{$active};
    $cb = $glade->get_widget('re_genotype_normal');
    $active = $cb->get_active();
    $model->set($row,7 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};
    $cb = $glade->get_widget('re_genotype_tumor');
    $active = $cb->get_active();
    $model->set($row,8 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};    
    $cb = $glade->get_widget('re_genotype_relapse');
    $active = $cb->get_active();
    $model->set($row,9 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};
    $cb = $glade->get_widget('re_somatic_status');
    $active = $cb->get_active();
    $model->set($row,11 => $rev_somatic_status{$active}) if exists $rev_somatic_status{$active};
    $cb = $glade->get_widget('re_data_needed');
    $active = $cb->get_active();
    $model->set($row,12 => $rdn{$active}) if exists $rdn{$active};
    
    my $tb = $glade->get_widget('re_text_view');    
    my ($s,$e) = $tb->get_buffer->get_bounds;
    my $text = $tb->get_buffer->get_text($s,$e,0);
    $text =~ tr/\n\t/  /;
    $model->set($row, 10 => $text) if defined $text;    
    return 1;
}

sub on_review_editor_destroy
{
    my ($self, $review_editor) = @_;
    print "caught destroy signal.\n";
    #saving window location
    my ($x, $y) = $review_editor->get_position;
    print "window position is $x, $y.\n";
    $self->{last_x} = $x;
    $self->{last_y} = $y;
    $review_editor->destroy;
    return 1;
}

sub on_review_button_clicked
{
    my ($self) = @_;
    my $g_handle = $self->g_handle;
    my $glade = new Gtk2::GladeXML("/gscuser/jschindl/svn/dev/perl_modules/Genome/manual_review/manual_review.glade","review_editor");
    $self->re_g_handle($glade);
    #$glade->signal_autoconnect_from_package($self);
    my $review_editor = $glade->get_widget("review_editor");
    if(defined $self->{last_x} && defined $self->{last_y})
    {
        $review_editor->move($self->{last_x},$self->{last_y});
    }
    my $review_list = $g_handle->get_widget("review_list");
    $review_editor->signal_connect("delete_event", sub { $self->on_review_editor_destroy($review_editor); });
    my $model = $review_list->get_model;
    my ($path,$column) = $review_list->get_cursor;
    my $row = $model->get_iter($path);
    my @val = $model->get($row,5,6,7,8,9,10,11,12);    
    my $re_hpaned = $glade->get_widget("re_hpaned");
    my ($width) = $review_editor->get_size_request;
    $re_hpaned->set_position($width/2.5);
    my $cancel = $glade->get_widget("re_cancel");
    $cancel->signal_connect("clicked", sub { $self->on_review_editor_destroy($review_editor); });
    my $ok = $glade->get_widget("re_ok");
    $ok->signal_connect("clicked", \&on_re_ok,[$self, $glade,$review_editor, $model, $row]);
    #set widgets

    my %pf = (Pass => 1, Fail => 2);
    my %dn = (Yes => 1, No => 2);
    my $cb = $glade->get_widget('re_genotype');
    $cb->set_active($iub_hash{$val[0]}) if(defined $val[0] && exists $iub_hash{$val[0]});
    $cb = $glade->get_widget('re_passfail');
    $cb->set_active($pf{$val[1]}) if(defined $val[1] && exists $pf{$val[1]});
    $cb = $glade->get_widget('re_genotype_normal');
    $cb->set_active($iub_hash{$val[2]}) if(defined $val[2] && exists $iub_hash{$val[2]});
    $cb = $glade->get_widget('re_genotype_tumor');
    $cb->set_active($iub_hash{$val[3]}) if(defined $val[3] && exists $iub_hash{$val[3]});
    $cb = $glade->get_widget('re_genotype_relapse');
    $cb->set_active($iub_hash{$val[4]}) if(defined $val[4] && exists $iub_hash{$val[4]});
    my $tb = $glade->get_widget('re_text_view');
    $tb->get_buffer->set_text($val[5]) if $val[5];
    $cb = $glade->get_widget('re_somatic_status');
    $cb->set_active($somatic_status{$val[6]}) if(defined $val[6] && exists $somatic_status{$val[6]}); 
    $cb = $glade->get_widget('re_data_needed');
    $cb->set_active($dn{$val[7]}) if(defined $val[7] && exists $dn{$val[7]});
    
    @val = $model->get($row,0,1);
    my $proj_dir = join '_',@val;
    $self->{pid} = $self->open_consed($proj_dir);
    return $review_editor;
}

sub display_row
{
    my ($self,$model, $row, $glade) = @_;
    
    my @val = $model->get($row,5,6,7,8,9,10,11,12);
    #set widgets

    my %pf = (Pass => 1, Fail => 2);
    my %dn = (Yes => 1, No => 2);
    my $cb = $glade->get_widget('re_genotype');
    if(defined $val[0] && exists $iub_hash{$val[0]})
    {
        $cb->set_active($iub_hash{$val[0]});        
    }
    else
    {
            $cb->set_active(undef);        
    }
    $cb = $glade->get_widget('re_passfail');
    
    if(defined $val[1] && exists $pf{$val[1]})
    {
        $cb->set_active($pf{$val[1]});
    }
    else
    {
        $cb->set_active(undef);
    }
    $cb = $glade->get_widget('re_genotype_normal');
    
    if(defined $val[2] && exists $iub_hash{$val[2]})
    {
        $cb->set_active($iub_hash{$val[2]});
    }
    else
    {
        $cb->set_active(undef);
    }
    $cb = $glade->get_widget('re_genotype_tumor');
    
    if(defined $val[3] && exists $iub_hash{$val[3]})
    {
        $cb->set_active($iub_hash{$val[3]});
    }
    else
    {
        $cb->set_active(undef);
    }
    $cb = $glade->get_widget('re_genotype_relapse');
    if(defined $val[4] && exists $iub_hash{$val[4]})
    {
        $cb->set_active($iub_hash{$val[4]});
    }
    else
    {
        $cb->set_active(undef);
    }
    
    $cb = $glade->get_widget('re_somatic_status');
    if(defined $val[6] && exists $somatic_status{$val[6]})
    {
        $cb->set_active($somatic_status{$val[6]});
    }
    else
    {
        $cb->set_active(undef);
    }
    $cb = $glade->get_widget('re_data_needed');
    if(defined $val[7] && exists $dn{$val[7]})
    {
        $cb->set_active($dn{$val[7]});
    }
    else
    {
        $cb->set_active(undef);
    }
    
    my $tb = $glade->get_widget('re_text_view');
    $tb->get_buffer->set_text($val[5]);

    @val = $model->get($row,0,1);
    my $proj_dir = join '_',@val;
    if($self->{pid}) {system "kill -9 $self->{pid}";}
    $self->{pid} = $self->open_consed($proj_dir);
    return ;
}

sub save_row
{
    my ($self,$model, $row, $glade) = @_;
    my %pf = (Pass => 1, Fail => 2);
    my %rpf = (1 => 'Pass', 2 => 'Fail');
    my %dn = (Yes => 1, No => 2);
    my %rdn = (1 => 'Yes', 2 => 'No');
    
    my $cb = $glade->get_widget('re_genotype');
    my $active = $cb->get_active();
    $model->set($row,5 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};
    $cb = $glade->get_widget('re_passfail');
    $active = $cb->get_active();
    $model->set($row,6 => $rpf{$active}) if exists $rpf{$active};
    $cb = $glade->get_widget('re_genotype_normal');
    $active = $cb->get_active();
    $model->set($row,7 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};
    $cb = $glade->get_widget('re_genotype_tumor');
    $active = $cb->get_active();
    $model->set($row,8 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};    
    $cb = $glade->get_widget('re_genotype_relapse');
    $active = $cb->get_active();
    $model->set($row,9 => $rev_iub_hash{$active}) if exists $rev_iub_hash{$active};
    $cb = $glade->get_widget('re_somatic_status');
    $active = $cb->get_active();
    $model->set($row,11 => $rev_somatic_status{$active}) if exists $rev_somatic_status{$active};
    $cb = $glade->get_widget('re_data_needed');
    $active = $cb->get_active();
    $model->set($row,12 => $rdn{$active}) if exists $rdn{$active};
    
    my $tb = $glade->get_widget('re_text_view');
    my ($s,$e) = $tb->get_buffer->get_bounds;
    my $text = $tb->get_buffer->get_text($s,$e,0);
    $text =~ tr/\n\t/  /;
    $model->set($row, 10 => $text) if defined $text;    

    return 1;

}

sub on_prev_button_clicked
{
    my ($self, $button) = @_;
    my $g_handle = $self->g_handle;
    my $review_list = $g_handle->get_widget("review_list");
    my $model = $review_list->get_model;
    my ($path,$column) = $review_list->get_cursor; 
    my $iter = $model->get_iter($path);  
    $self->save_row($model, $iter, $self->re_g_handle) if $self->re_g_handle; 
    return unless $path;
    return unless $path->prev;
    $iter = $model->get_iter($path);
    $self->display_row($model, $iter, $self->re_g_handle) if ($self->re_g_handle && $path);
    print "attempted to reset cursor.'\n";
    $review_list->set_cursor($path);

}

sub on_next_button_clicked
{
    my ($self, $button) = @_;
    my $g_handle = $self->g_handle;
    my $review_list = $g_handle->get_widget("review_list");
    my $model = $review_list->get_model;
    my ($path,$column) = $review_list->get_cursor; 
    my $iter = $model->get_iter($path);   
    $self->save_row($model, $iter, $self->re_g_handle) if $self->re_g_handle; 
    return unless $path;
    $path->next;
    $iter = $model->get_iter($path);
    $self->display_row($model, $iter, $self->re_g_handle) if ($self->re_g_handle && $path);
    $review_list->set_cursor($path);
    #set widgets

    return ;
}

sub gtk_main_quit
{
    Gtk2->main_quit;	
}

1;
