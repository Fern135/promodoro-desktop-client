import asyncio
from typing import cast # use this to literally cast what it's supposed to expect.

from plyer import notification as _notification
from plyer.facades import Notification

# plyer's lazy Proxy confuses type checkers; tell Pylance the real type.
notification = cast(Notification, _notification)

default_timer = 25
default_rest  = 5
yes_list = ["yes", "y"]


def notify(title="ALERT", message="Time for a break", urgent=False):
    notification.notify(
        title=title,
        message=message,
        timeout=10,
        hints={"urgency": 2} if urgent else {},  # 2 = critical
    )


async def countdown(minutes, label="Work"):
    total = minutes * 60
    for remaining in range(total, 0, -1):
        mins, secs = divmod(remaining, 60)
        print(f"\r{label}: {mins:02d}:{secs:02d}", end="", flush=True)
        await asyncio.sleep(1)
    print(f"\r{label}: 00:00  done!")

async def timer(sessions):
    for _ in range(1, sessions + 1):
        await countdown(default_timer, "Work")
        notify("Pomodoro", "Time for a break", urgent=True)
        await countdown(default_rest, "Break")
        notify("Pomodoro", "Back to work")
    
async def main():
    while True:
        try:
            usr = input("How many sessions would you be doing? (q to quit)\t").strip().lower()
        except (EOFError, KeyboardInterrupt):
            print("\nBye!")
            return
        
        if usr in ("q", "quit"):
            print("Bye!")
            return
        
        try:
            usr = int(usr)
        except ValueError:
            print("Please enter a whole number.")
            continue

        if usr < 1:
            print("Enter at least 1 session.")
            continue

        if usr > 10:
            try:
                check = input("Too many sessions, are you sure? (y/n) ").lower().strip()
            except EOFError:
                print("\nBye!")
                return
            if check not in yes_list:
                continue

        await timer(usr)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nBye!")
