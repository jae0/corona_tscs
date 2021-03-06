// Coronavirus tracking model 
// Robert Kubinec
// New York University Abu Dhabi
// March 20, 2020

data {
    int time_all;
    int num_country;
    int cases[num_country,time_all];
    int tests[num_country,time_all];
    int time_outbreak[num_country,time_all];
    int outbreak[num_country,time_all];
    matrix[time_all,3] ortho_time;
    vector[num_country] suppress;
    int country_pop[num_country];
}
transformed data {
  matrix[num_country,time_all] time_outbreak_trans1; // convert raw time numbers to ortho-normal polynomials
  matrix[num_country,time_all] time_outbreak_trans2; // convert raw time numbers to ortho-normal polynomials
  matrix[num_country,time_all] time_outbreak_trans3; // convert raw time numbers to ortho-normal polynomials
  vector[time_all] count_outbreak = rep_vector(0,num_country); // number of countries with infection at time point t
  
  for(t in 1:time_all) {
    for(n in 1:num_country)
        count_outbreak[t] += cases[n,t] > 0 ? 1 : 0;
  }
  
  // mean-center & standardize
  
  count_outbreak = (count_outbreak - mean(count_outbreak))/sd(count_outbreak);
  
  for(t in 1:time_all) {
    for(n in 1:num_country) {
      if(time_outbreak[n,t]>0) {
        time_outbreak_trans1[n,t] = ortho_time[time_outbreak[n,t],1];
        time_outbreak_trans2[n,t] = ortho_time[time_outbreak[n,t],2];
        time_outbreak_trans3[n,t] = ortho_time[time_outbreak[n,t],3];
      } else {
        time_outbreak_trans1[n,t] = 0;
        time_outbreak_trans2[n,t] = 0;
        time_outbreak_trans3[n,t] = 0;
      }
    }
  }
    
}
parameters {
  vector[3] poly; // polinomial function of time
  real<lower=0> phi; // shape parameter for infected
  real<lower=0,upper=1> finding; // difficulty of identifying infected cases 
  real<lower=0> world_infect1; // rate of outbreak crossing borders
  real<lower=0> world_infect2; // effect of world-wike infection on domestic rate
  real suppress_effect; // suppression effect of govt. measures
  vector[num_country] country_test; // unobserved rate at which countries are willing to test vs. number of infected
  vector[num_country] country_test2; // unobserved rate at which countries are willing to test vs. number of infected
  real out_cut; // cutpoint between no outbreak/outbreak
  vector[3] alpha; // intercept for number of cases as a proportion of tests
  matrix<lower=0,upper=1>[num_country,time_all] num_infected; // modeled infection rates
  vector[num_country-1] country_int_free; // varying intercepts by country - 1 for identification
}
transformed parameters {
  vector[num_country] country_int = append_row(0,country_int_free);
}
model {
  
  poly[1] ~ normal(0,5); // should be small 
  poly[2] ~ normal(0,1);
  poly[3] ~ normal(0,0.5);
  out_cut ~ normal(-5,1); // very low as it equals beginning of outbreak
  phi ~ lognormal(6,.5); // should be large to prevent very wide probability intervals
  world_infect1 ~ exponential(1); 
  world_infect2 ~ exponential(1);
  suppress_effect ~ normal(0,1);
  alpha[1] ~ normal(-5,1);
  alpha[2] ~ normal(-5,1);
  alpha[3] ~ normal(-2,1);
  finding ~ normal(0,1);
  country_int_free ~ normal(0,1);
  country_test ~ normal(0,1); // more likely near the middle than the ends
  country_test2 ~ normal(0,.25);
  to_vector(num_infected[,1]) ~ beta_proportion(0.00001,100); // no cases in t=1
  
  // first model probability of infection
  
  //next model the true infection rate as a function of time since outbreak
  for (t in 2:time_all) {
    for(n in 1:num_country) {
      if(outbreak[n,t]>0) {

        //outbreak has started
        target += log_inv_logit(country_int[n] + world_infect1*count_outbreak[t] - out_cut);

        //current number of infected (unobserved)
        num_infected[n,t] ~ beta_proportion(inv_logit(alpha[1] + poly[1]*time_outbreak_trans1[n,t] +
                                      poly[2]*time_outbreak_trans2[n,t] +
                                      poly[3]*time_outbreak_trans3[n,t] +
                                      world_infect2*count_outbreak[t] +
                                      suppress_effect*suppress[n]*time_outbreak_trans1[n,t]),phi);

        // cases/tests = observed data

        tests[n,t] ~ binomial_logit(country_pop[n],alpha[2] + country_test[n]*num_infected[n,t] +
                            country_test2[n]*sqrt(num_infected[n,t]));

        cases[n,t] ~ binomial_logit(tests[n,t],alpha[3] + finding*num_infected[n,t]);


      } else {
        target += log1m_inv_logit(country_int[n] + world_infect1*count_outbreak[t] - out_cut);
        num_infected[n,t] ~ beta_proportion(.00001,100); // assume very few cases till we get some report of transmission
      }

    }

  }
  
  
}

