import random
import string
import crypt

def create_password(password_length):
    chars = string.ascii_letters + string.digits + "'!@#$%^&*()"
    result_str = ''.join(random.choice(chars) for i in range(password_length))
    return result_str

if __name__ == '__main__':
    password_length = 10
    row_password = create_password(password_length)
    print("Your password is:", row_password)
    print("Your crypted password is:", crypt.crypt(row_password))
