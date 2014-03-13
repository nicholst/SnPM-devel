% Mfile snpm_pi_TwoSampT
% SnPM PlugIn design module - 2 group, 1 scan per subject
% 2 Groups: Two Sample T test; 1 scan per subject
% FORMAT snpm_pi_TwoSampT 
%
% See body of snpm_ui for definition of PlugIn interface.
%_______________________________________________________________________
%
% snpm_pi_TwoSampT is a PlugIn for the SnPM design set-up program,
% creating design and permutation matrix appropriate for two group
% analyses where there is just *one* scan per subject.
%
% Keep in mind that when only 1 scan per subject is used there is no way to
% control for anatomical differences, hence the differences identified will
% be attributable to both functional and anatomical differences between the
% groups.  
%
% A common source of between group anatomical differences is age;
% older subjects tend to have larger ventricles and thinner gray matter
% relative to younger subjects.  One approach to address this difference is
% to include a linear confounding covariate of age; alternatively, a
% dichotomous covariate (consisting of just 0's and 1's) indicating young/old
% can be used.  Including such covariates will ensure that group differences
% are not atributable to linear (or constant, for 0/1 covariate) effects of
% age.  Hence, with both of these approaches if ages are not equally
% distributed between groups then including such covariates can reduce the
% signal attributable to group differences, since some of the signal could
% just be due to age.
%
%
%-Number of permutations
%=======================================================================
%
% There are nTot-choose-nGrp possible permutations, where 
% nTot is the total number of subjects (and scans) and nGrp is the
% size of one of the groups.
%
%	prod(1:nTot)/prod(1:nGrp)^2
% 
%
%-Prompts
%=======================================================================
%
% 'Select all scans':  Enter the scans to be analyzed; the order 
% is not important as the specification of which scans belong to which
% groups will be specified subsequently.
%
% '# of confounding covariates' & '[<len>] - Covariate <num>': Use these
% prompts to specify a covariate of no interest.  As mentioned above,
% fitting a confounding covariate of age may be desirable.
%
% 'Enter Subject index: (A/B)':  Use A's & B's to indicate which 
% scans belong to which group.  Positive effects are Group A - Group B.
% You must enter one letter for each scan entered above; this beta
% version only supports equal group sizes.
% 
% '<nPerms> Perms.  Use approx. test':  This prompt will inform you of the
% number of possible permutations, that is, the number of ways the group
% labels can be arranged under the assumption that there is no group
% effect.  Fewer than 200 permutations is undesirable; more than 10,000
% is unnecessary.  If the number of permutations is much greater than 10,000
% you should use an approximate test.  Answering 'y' will produce another
% prompt... 
% '# perms. to use? (Max <MaxnPerms>)': 10,000 permutations is regarded as
% a sufficient number to characterize the permutation distribution well.
%
%
%-Variable "decoder" - This PlugIn supplies the following:
%=======================================================================
% - core -
% P             - string matrix of Filenames corresponding to observations
% iGloNorm      - Global normalisation code, or allowable codes
%               - Names of columns of design matrix subpartitions
% PiCond        - Permuted conditions matrix, one labelling per row, actual
%                 labelling on first row
% sPiCond       - String describing permutations in PiCond
% sHCform       - String for computation of HC design matrix partitions
%                 permutations indexed by perm in snpm_cp
% CONT          - single contrast for examination, a row vector
% sDesign       - String defining the design
% sDesSave      - String of PlugIn variables to save to cfg file
%
% - design -
% H,Hnames      - Condition partition of design matrix, & effect names
% B,Bnames      - Block partition (constant term), & effect names
%
% - extra -
% iCond         - Condition indicator vector
% GrpCnt        - 2-vector of group counts
%
%_______________________________________________________________________
% Based on snpm_SSA2x.m v1.7
% @(#)snpm_MG2x.m	3.2	Andrew Holmes, Thomas Nichols 04/06/08
%	$Id: snpm_pi_TwoSampT.m,v 8.1 2009/01/29 15:02:57 nichols Exp $	

%-----------------------------functions-called------------------------
% spm_DesMtx
% spm_select
% spm_input
%-----------------------------functions-called------------------------

% 
% Note:  For a multisubject, no-replication design,
% exchagiblity is guaranteed for all observations by random selection of
% subjects from the populations of interest.  Hence, Xblk is all scans.
%

%-Initialisation
%-----------------------------------------------------------------------
nCond    = 2;			% Number of conditions (groups)
iGloNorm = '123';		% Allowable Global norm. codes
sDesSave = 'iCond GrpCnt';	% PlugIn variables to save in cfg file
% rand('seed',sum(100*clock));	% Initialise random number generator

%-Get filenames and iCond, the condition labels
%=======================================================================
P = spm_select(Inf,'image','Select all scans');
nScan = size(P,1);

%-Get the condition (group) labels
%=======================================================================
while(1)
    tmp=['Enter subject index: (A/B) [',int2str(nScan),']'];
    iCond = spm_input(tmp,'+1','s');
    %-Convert A/B notation to +/-1 vector - assume A-B is of interest
    iCond = abs(upper(iCond(~isspace(iCond))));
    iCond = iCond-min(iCond); iCond = -iCond/max([1,iCond])*2+1;
    %-Check validity of iCond
    if sum(iCond==-1)+sum(iCond==1)~=nScan
        fprintf(2,'%cMore than 2 types of indicies entered',7)
    elseif length(iCond)~=nScan
	fprintf(2,'%cEnter indicies for exactly %d scans',7,nScan)
    else
	break	
    end	
end
nFlip = sum(iCond==-1);

%-Get confounding covariates
%-----------------------------------------------------------------------
G = []; Gnames = ''; Gc = []; Gcnames = ''; q = nScan;
g = spm_input('# of confounding covariates','+1','0|1|2|3|4|5|>',0:6,1);
if (g == 6), g = spm_input('# of confounding covariates','+1'); end
while size(Gc,2) < g
  nGcs = size(Gc,2);
  d = spm_input(sprintf('[%d] - Covariate %d',[q,nGcs + 1]),'0');
  if (size(d,1) == 1), d = d'; end
  if size(d,1) == q
    %-Save raw covariates for printing later on
    Gc = [Gc,d];
    %-Always Centre the covariate
    bCntr = 1;	    
    if bCntr, d  = d - ones(q,1)*mean(d); str=''; else, str='r'; end
    G = [G, d];
    dnames = [str,'ConfCov#',int2str(nGcs+1)];
    for i = nGcs+1:nGcs+size(d,1)
      dnames = str2mat(dnames,['ConfCov#',int2str(i)]); end
    Gcnames = str2mat(Gcnames,dnames);
  end
end
%-Strip off blank line from str2mat concatenations
if size(Gc,2), Gcnames(1,:)=[]; end
%-Since no FxC interactions these are the same
Gnames = Gcnames;


%-Compute permutations of conditions
%=======================================================================
%-Compute permutations for a single exchangability block
%-----------------------------------------------------------------------
%-NB: m-Choose-n = exp(gammaln(m+1)-gammaln(m-n+1)-gammaln(n+1))
nPiCond = round(exp(gammaln(nScan+1)-gammaln(nScan-nFlip+1)-gammaln(nFlip+1)));
bAproxTst = spm_input(sprintf('%d Perms. Use approx. test?',nPiCond),...
							'+1','y/n')=='y';
if (bAproxTst)
  tmp = 0;
  while ((tmp>nPiCond) | (tmp==0) )
    tmp = spm_input(sprintf('# perms. to use? (Max %d)',nPiCond),'+0');
    tmp = floor(max([0,tmp]));
  end
  if (tmp==nPiCond), bAproxTst=0; else, nPiCond=tmp; end
end

%-Two methods for computing permutations, random and exact; exact
% is efficient, but a memory hog; Random is slow but requires little
% memory.
%-We use the exact one when the nScan is small enough; for nScan=12,
% PiCond will initially take 384KB RAM, for nScan=14, 1.75MB, so we 
% use 12 as a cut off. (2^nScan*nScan * 8bytes/element).  
%-If user wants all perms, then random method would seem to take an
% absurdly long time, so exact is used.

if nScan<=12 | ~bAproxTst                    % exact method

    %-Generate all labellings of nScan scans as +/- 1
    PiCond=[];
    for i=0:nScan-1
	PiCond=[ones(2^i,1),PiCond;-ones(2^i,1),PiCond];
    end
    %-Trim to labellings with correct group numbers
    PiCond=PiCond(sum(PiCond'==-1)==nFlip,:);

    %-Only do half the work, if possible
    bhPerms=0;
    if ~bAproxTst & (nFlip==nScan/2) % balanced group numbers
	% Here, PiCond should *always* satisfy:
	% all(all(PiCond(PiCond(:,1)==1,:)==flipud(-PiCond(PiCond(:,1)==-1,:))))
	PiCond=PiCond(PiCond(:,1)==1,:);
	bhPerms=1;
    elseif bAproxTst                 % pick random supsample of perms
	tmp=randperm(size(PiCond,1));
	PiCond=PiCond(tmp(1:nPiCond),:);
        % Note we may have missed iCond!  We catch this below.	
    end	

else                                          % random method
    
    % Allocate final result
    PiCond = zeros(nPiCond,nScan);

    % Fill first row  
    PiCond(1,:) = iCond;
    % Fill subsequent rows, checking that we're not repeating  
    for i=2:nPiCond
      tmp=PiCond(i-1,randperm(nScan));
      while any(all(PiCond(1:(i-1),:)'==meshgrid(tmp,1:(i-1))'))
	tmp=PiCond(i-1,randperm(nScan));
      end
      PiCond(i,:)=tmp;
    end      

    bhPerms=0;    
end

%-Check PiConds sum to nGrp1-nGrp2
if ~all(all(PiCond*ones(nScan,1)==nScan-2*nFlip))
	error('Invalid PiCond computed!'), end

%-Find (maybe) iCond in PiCond, move iCond to 1st; negate if neccesary
%-----------------------------------------------------------------------
perm = find(all((meshgrid(iCond,1:size(PiCond,1))==PiCond)'));
if (bhPerms)
    perm=[perm,-find(all((meshgrid(iCond,1:size(PiCond,1))==-PiCond)'))];
end
if length(perm)==1
    if (perm<0), PiCond=-PiCond; perm=-perm; end
    %-Actual labelling must be at top of PiCond
    if (perm~=1)
	PiCond(perm,:)=[];
	PiCond=[iCond;PiCond];
    end
    if ~bAproxTst    
	%-Randomise order of PiConds, unless already randomized
	% Allows interim analysis	
	PiCond=[PiCond(1,:);PiCond(randperm(size(PiCond,1)-1)+1,:)];
    end	
elseif length(perm)==0 & (nScan<=12) & bAproxTst
    % Special case where we missed iCond; order of perms is random 
    % so can we can just replace first perm.
    PiCond(1,:) = iCond;
    perm = 1;
else    
    error(['Bad PiCond (' num2str(perm) ')'])
end    


%-Form non-null design matrix partitions (Globals handled later)
%=======================================================================
%-Form for HC computation at permutation perm
sHCform    = 'spm_DesMtx(PiCond(perm,:),''-'',''Cond'')';
%-Condition partition
[H,Hnames] = spm_DesMtx(iCond,'-','Cond');
%-Contrast of condition effects
% (spm_DesMtx puts condition effects in index order)
CONT       = [-1,1];
%-No block/constant
B=[]; Bnames='';


%-Design description
%-----------------------------------------------------------------------
GrpCnt = [nScan-nFlip nFlip];
sDesign = sprintf('2 Groups: Two Sample T test; 1 scan per subject: %d(GrpA),%d(GrpB)',GrpCnt);
sPiCond = sprintf('%d permutations of conditions, bhPerms=%d',size(PiCond,1)*(bhPerms+1),bhPerms);
