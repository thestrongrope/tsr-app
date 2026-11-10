-- First start only. Lets the app user own the synthetic database that
-- `synth-build` creates. The generator makes tsr_synth itself (with its marker
-- table); an empty database made here would be refused as "may hold real data".
GRANT ALL PRIVILEGES ON `tsr_synth`.* TO 'tsr_user'@'%';
FLUSH PRIVILEGES;
