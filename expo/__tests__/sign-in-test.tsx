import { fireEvent, render, screen } from '@testing-library/react-native';
import { signIn } from '../src/auth';
import { SignIn } from '../src/components/SignIn';

jest.mock('../src/auth', () => ({ signIn: jest.fn(async () => {}), signUp: jest.fn() }));
// Uniwind compiles classes inside Metro; Jest has no Metro, so the one hook gets plain values.
jest.mock('uniwind', () => ({ useCSSVariable: (names: string[]) => names.map(() => 'black') }));

describe('<SignIn />', () => {
  test('signs in with the email trimmed, from the boxes a Maestro flow types into', async () => {
    await render(<SignIn />);
    await fireEvent.changeText(screen.getByTestId('email'), '  ana@field.test ');
    await fireEvent.changeText(screen.getByTestId('password'), 'secret-1');
    await fireEvent.press(screen.getByTestId('sign-in'));
    expect(signIn).toHaveBeenCalledWith('ana@field.test', 'secret-1');
  });
});
