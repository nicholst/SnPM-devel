### SnPM: Statistical nonParametric Mapping

The <b>S</b>tatistical <b>n</b>on-<b>P</b>arametric <b>M</b>apping (SnPM) toolbox provides an extensible framework for voxel level non-parametric permutation/randomisation tests of functional Neuroimaging experiments with independent observations. 

The SnPM toolbox provides an alternative to the Statistics section of [SPM](http://www.fil.ion.ucl.ac.uk/spm/). SnPM uses the General Linear Model to construct pseudo t-statistic images, which are then assessed for significance using a standard non-parametric multiple comparisons procedure based on randomisation/permutation testing. It is most suitable for single subject PET/SPECT analyses, or designs with low degrees of freedom available for variance estimation. In these situations the freedom to use weighted locally pooled variance estimates, or variance smoothing, makes the non-parametric approach considerably more powerful than conventional parametric approaches, as are implemented in SPM. Further, the non-parametric approach is always valid, given only minimal assumptions.

##### Testing
To run the test suite you will first have to create a set of ground truth data. Then, the tests can be started with:
```
import matlab.unittest.TestSuite;
suite = TestSuite.fromFolder(fullfile(spm_str_manip(which('snpm'), 'h'), 'test'));
result = run(suite);
```