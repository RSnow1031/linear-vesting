// contracts/LinearVesting.sol
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "./LinearVesting.sol";

/**
 * @title MockLinearVesting
 * WARNING: use only for testing and debugging purpose
 */
contract MockLinearVesting is LinearVesting{

    uint256 mockTime = 0;

    constructor() LinearVesting(){
    }

    function setCurrentTime(uint256 _time)
        external{
        mockTime = _time;
    }

    function getCurrentTime()
        internal
        virtual
        override
        view
        returns(uint256){
        return mockTime;
    }
}