use starknet::ContractAddress;

#[starknet::interface]
trait ISalakiCoin<T> {
    fn get_name(self: @T) -> felt252;
    fn get_symbol(self: @T) -> felt252;
    fn get_decimals(self: @T) -> u8;
    fn get_total_supply(self: @T) -> u256;
    fn balance_of(self: @T, owner: ContractAddress) -> u256;
    fn transfer(ref self: T, to: ContractAddress, amount: u256) -> bool;
    fn transfer_from(ref self: T, from: ContractAddress, to: ContractAddress, amount: u256);
    fn approve(ref self: T, spender: ContractAddress, amount: u256);
    fn increase_allowance(ref self: T, spender: ContractAddress, added_value: u256);
    fn decrease_allowance(ref self: T, spender: ContractAddress, subtracted_value: u256);
}

#[starknet::contract]
mod SalakiCoin {
    use starknet::{ContractAddress, get_caller_address};
    use super::ISalakiCoin;
    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: LegacyMap<ContractAddress, u256>,
        allowances: LegacyMap<(ContractAddress, ContractAddress), u256>,
    }

    // EVENTS
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Approval: Approval,
        Transfer: Transfer
    }

    #[derive(Drop, starknet::Event)]
    struct Transfer {
        from: ContractAddress,
        to: ContractAddress,
        value: u256
    }

    #[derive(Drop, starknet::Event)]
    struct Approval {
        owner: ContractAddress,
        spender: ContractAddress,
        value: u256,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        recipient: ContractAddress
    ) {
        assert(!recipient.is_zero(), 'transfer to zero address');
        self.name.write('SalakiCoin');
        self.symbol.write('SCN');
        self.decimals.write(18);
        self.total_supply.write(1000000);
        self.balances.write(recipient, 1000000);
        self.emit(Transfer { from: contract_address_const::<0>(), to: recipient, value: 1000000 });
    }

    #[external(v0)]
    impl ISalakiCoinImpl of ISalakiCoin<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, owner: ContractAddress) -> u256 {
            self.balances.read(owner)
        }

        fn transfer(ref self: ContractState, to: ContractAddress, amount: u256) -> bool {
            let caller = get_caller_address();
            self.transfer_helper(caller, to, amount);
            true
        }
        fn transfer_from(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) {
            let caller = get_caller_address();
            let my_allowance = self.allowances.read((from, caller));

            assert(my_allowance > 0, 'You have no token approved');
            assert(amount <= my_allowance, 'Amount Not Allowed');
            self.spend_allowance(from, caller, amount);
            self.transfer_helper(from, to, amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) + added_value
                );
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.read((caller, spender)) - subtracted_value
                );
        }
    }
    #[generate_trait]
    impl HelperImpl of HelperTrait {
        fn transfer_helper(
            ref self: ContractState, from: ContractAddress, to: ContractAddress, amount: u256
        ) -> bool {
            let sender_balance = self.balance_of(from);

            assert(!from.is_zero(), 'transfer from 0');
            assert(!to.is_zero(), 'transfer to 0');
            assert(sender_balance >= amount, 'Insufficient fund');
            self.balances.write(from, self.balances.read(from) - amount);
            self.balances.write(to, self.balances.read(to) + amount);
            self.emit(Transfer { from, to, value: amount });
            true
        }

        fn approve_helper(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            assert(!owner.is_zero(), 'approve from 0');
            assert(!spender.is_zero(), 'approve to 0');

            self.allowances.write((owner, spender), amount);

            self.emit(Approval { owner, spender, value: amount })
        }

        fn spend_allowance(
            ref self: ContractState, owner: ContractAddress, spender: ContractAddress, amount: u256
        ) {
            let current_allowance = self.allowances.read((owner, spender));
            self.approve_helper(owner, spender, current_allowance - amount);
        }
    }
}

