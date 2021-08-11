import { parseEther } from '@ethersproject/units';

export const GOVERN_PROPOSAL_DEPOSIT = 100;
export const GOVERN_VOTE_TIMEOUT = 20;
export const SLASH_TIMEOUT = 50;
export const MIN_VALIDATOR_NUM = 1;
export const MAX_VALIDATOR_NUM = 20;
export const MIN_STAKING_POOL = parseEther('4');
export const ADVANCE_NOTICE_PERIOD = 100;
export const DPOS_GO_LIVE_TIMEOUT = 20;

export const MIN_SELF_STAKE = parseEther('2');
export const CANDIDATE_STAKE = parseEther('3'); // smaller than MIN_STAKING_POOL for testing purpose
export const DELEGATOR_STAKE = parseEther('4');

export const COMMISSION_RATE = 100;
export const RATE_LOCK_END_TIME = 2;

export const HASHED_NULL = '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470';
